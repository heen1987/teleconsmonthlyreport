#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

cd backend

.venv/bin/python - <<'PY'
import time

from fastapi.testclient import TestClient
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus, MeetingStatus, MinutesStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
employee_no = f"DIST{stamp}"
password = f"distpw{stamp}"
project_id = f"PRJ-DIST-{stamp}"
meeting_id = f"MTG-DIST-{stamp}"
draft_meeting_id = f"MTG-DIST-DRAFT-{stamp}"
analysis_id = f"ANL-DIST-{stamp}"
draft_analysis_id = f"ANL-DIST-DRAFT-{stamp}"
email = f"dist{stamp}@local.test"
outsider_email = f"outsider{stamp}@local.test"

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "회의록 배포 smoke 테스트 요약입니다.",
    "transcript_segments": [
        {
            "segment_id": "seg-1",
            "speaker": None,
            "start_ms": 0,
            "end_ms": 5000,
            "text": "승인된 회의록을 배포합니다.",
        }
    ],
    "decisions": [
        {"content": "배포 기능은 승인 후에만 노출한다.", "confidence": 0.9},
    ],
    "action_items": [
        {
            "title": "배포 이력 확인",
            "assignee": None,
            "due_date": None,
            "target_module": "task",
            "priority": "high",
            "confidence": 0.8,
            "task_conversion_policy": "manual_review_required",
            "task_conversion_status": "candidate",
        }
    ],
    "risks": [
        {"title": "실제 SMTP 전환 전까지 dev_log로 운영", "level": "medium", "confidence": 0.7},
    ],
    "required_resources": [
        {"name": "SMTP 계정", "resource_type": "software", "quantity": 1, "confidence": 0.7},
    ],
    "requires_human_approval": True,
}

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Distribution Smoke",
                email=email,
                role="pm",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Distribution Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'pm')
            """,
            (project_id, user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by, transcript)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                meeting_id,
                project_id,
                "Distribution Smoke Meeting",
                MeetingStatus.APPROVED.value,
                user["user_id"],
                "승인된 회의록을 배포합니다.",
            ),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json, approved_at)
            VALUES (%s, %s, %s, %s, %s, %s, now())
            """,
            (
                analysis_id,
                meeting_id,
                MinutesStatus.APPROVED.value,
                "smoke-model",
                result_json["summary"],
                Jsonb(result_json),
            ),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                draft_meeting_id,
                project_id,
                "Distribution Draft Meeting",
                MeetingStatus.REVIEW_REQUIRED.value,
                user["user_id"],
            ),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                draft_analysis_id,
                draft_meeting_id,
                MinutesStatus.DRAFT.value,
                "smoke-model",
                result_json["summary"],
                Jsonb(result_json),
            ),
        )

login = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": password},
)
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

draft_preview = client.get(
    f"/meetings/{draft_meeting_id}/distribution-preview",
    headers=headers,
)
assert draft_preview.status_code == 409, draft_preview.text

preview = client.get(f"/meetings/{meeting_id}/distribution-preview", headers=headers)
assert preview.status_code == 200, preview.text
preview_body = preview.json()
assert preview_body["screen_id"] == "W-006", preview_body
assert preview_body["can_distribute"] is True, preview_body
assert preview_body["delivery_mode"] == "dev_log", preview_body
assert preview_body["recipients"][0]["email"] == email, preview_body
assert "회의록" in preview_body["subject"], preview_body

send = client.post(
    f"/meetings/{meeting_id}/distribute",
    headers=headers,
    json={
        "subject": preview_body["subject"],
        "body": preview_body["body"],
        "recipients": [{"email": outsider_email, "name": "Outsider", "role": "external"}],
    },
)
assert send.status_code == 200, send.text
send_body = send.json()
assert send_body["status"] == "sent", send_body
assert send_body["delivery_mode"] == "dev_log", send_body
assert len(send_body["attempts"]) == len(preview_body["recipients"]), send_body
assert send_body["attempts"][0]["status"] == "sent", send_body
assert send_body["attempts"][0]["recipient_email"] == email, send_body
assert outsider_email not in {attempt["recipient_email"] for attempt in send_body["attempts"]}, send_body

logs = client.get(f"/meetings/{meeting_id}/distributions", headers=headers)
assert logs.status_code == 200, logs.text
assert logs.json()[0]["distribution_id"] == send_body["distribution_id"], logs.text

duplicate = client.post(
    f"/meetings/{meeting_id}/distribute",
    headers=headers,
    json={
        "subject": preview_body["subject"],
        "body": preview_body["body"],
    "recipients": preview_body["recipients"],
    },
)
assert duplicate.status_code == 409, duplicate.text

review = client.get(f"/meetings/{meeting_id}/review-package", headers=headers)
assert review.status_code == 200, review.text
assert review.json()["meeting"]["status"] == MeetingStatus.DISTRIBUTED.value, review.text

print(
    {
        "meeting_id": meeting_id,
        "preview": preview.status_code,
        "distribution": send_body["status"],
        "attempts": len(send_body["attempts"]),
        "duplicate": duplicate.status_code,
    }
)
PY

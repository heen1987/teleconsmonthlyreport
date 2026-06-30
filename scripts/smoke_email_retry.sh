#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

cd backend

.venv/bin/python - <<'PY'
import time
import uuid

from fastapi.testclient import TestClient
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus, DistributionStatus, MeetingStatus, MinutesStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
employee_no = f"DRTY{stamp}"
password = f"retrypw{stamp}"
project_id = f"PRJ-DRTY-{stamp}"
manual_meeting_id = f"MTG-DRTY-MANUAL-{stamp}"
due_meeting_id = f"MTG-DRTY-DUE-{stamp}"
manual_analysis_id = f"ANL-DRTY-MANUAL-{stamp}"
due_analysis_id = f"ANL-DRTY-DUE-{stamp}"
manual_distribution_id = f"DST-DRTY-MANUAL-{stamp}"
due_distribution_id = f"DST-DRTY-DUE-{stamp}"
email = f"retry{stamp}@local.test"

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "이메일 재시도 smoke 테스트 요약입니다.",
    "transcript_segments": [],
    "decisions": [],
    "action_items": [],
    "risks": [],
    "required_resources": [],
    "requires_human_approval": True,
}


def insert_failed_distribution(cursor, meeting_id, analysis_id, distribution_id, status):
    recipients = [{"email": email, "name": "Retry Smoke", "role": "pm"}]
    cursor.execute(
        """
        INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            meeting_id,
            project_id,
            f"Email Retry {meeting_id}",
            MeetingStatus.DISTRIBUTION_FAILED.value,
            user["user_id"],
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
            "retry-smoke-model",
            result_json["summary"],
            Jsonb(result_json),
        ),
    )
    cursor.execute(
        """
        INSERT INTO email_distributions
            (
                distribution_id,
                meeting_id,
                analysis_id,
                subject,
                body,
                recipients,
                status,
                delivery_mode,
                requested_by,
                attempt_count,
                last_error,
                next_retry_at
            )
        VALUES (%s, %s, %s, %s, %s, %s, %s, 'smtp', %s, 1, %s, now() - interval '1 minute')
        """,
        (
            distribution_id,
            meeting_id,
            analysis_id,
            "[AI-PMS] Retry Smoke",
            "Retry body",
            Jsonb(recipients),
            status,
            user["user_id"],
            "SMTP host is not configured",
        ),
    )
    cursor.execute(
        """
        INSERT INTO email_delivery_attempts
            (
                attempt_id,
                distribution_id,
                recipient_email,
                recipient_name,
                status,
                attempt_no,
                error_message
            )
        VALUES (%s, %s, %s, %s, %s, 1, %s)
        """,
        (
            f"EDA-DRTY-{uuid.uuid4().hex[:12]}",
            distribution_id,
            email,
            "Retry Smoke",
            DistributionStatus.FAILED.value,
            "SMTP host is not configured",
        ),
    )


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Email Retry Smoke",
                email=email,
                role="pm",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Email Retry Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'pm')
            """,
            (project_id, user["user_id"]),
        )
        insert_failed_distribution(
            cursor,
            manual_meeting_id,
            manual_analysis_id,
            manual_distribution_id,
            DistributionStatus.FAILED.value,
        )
        insert_failed_distribution(
            cursor,
            due_meeting_id,
            due_analysis_id,
            due_distribution_id,
            DistributionStatus.RETRY_WAIT.value,
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

manual_retry = client.post(
    f"/meetings/{manual_meeting_id}/distributions/{manual_distribution_id}/retry",
    headers=headers,
)
assert manual_retry.status_code == 200, manual_retry.text
manual_body = manual_retry.json()
assert manual_body["status"] == "sent", manual_body
assert manual_body["delivery_mode"] == "dev_log", manual_body
assert manual_body["attempt_count"] == 2, manual_body
assert manual_body["attempts"][-1]["attempt_no"] == 2, manual_body
assert manual_body["last_error"] is None, manual_body

sent_retry = client.post(
    f"/meetings/{manual_meeting_id}/distributions/{manual_distribution_id}/retry",
    headers=headers,
)
assert sent_retry.status_code == 409, sent_retry.text

due_retry = client.post("/distributions/retry-due", headers=headers, json={"limit": 5})
assert due_retry.status_code == 200, due_retry.text
due_body = due_retry.json()
assert len(due_body) == 1, due_body
assert due_body[0]["distribution_id"] == due_distribution_id, due_body
assert due_body[0]["status"] == "sent", due_body
assert due_body[0]["attempt_count"] == 2, due_body

print(
    {
        "manual_distribution": manual_body["status"],
        "manual_attempts": len(manual_body["attempts"]),
        "sent_retry": sent_retry.status_code,
        "due_retry": len(due_body),
    }
)
PY

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
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
employee_no = f"KNO{stamp}"
password = f"knopw{stamp}"
project_id = f"PRJ-KNO-{stamp}"
meeting_id = f"MTG-KNO-{stamp}"
analysis_id = f"ANL-KNO-{stamp}"

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "프로젝트 지식 인덱싱 smoke 요약",
    "transcript_segments": [
        {
            "segment_id": "seg-1",
            "speaker": None,
            "text": "결정사항과 액션아이템을 프로젝트 지식으로 축적합니다.",
            "start_ms": 0,
            "end_ms": 3000,
        }
    ],
    "decisions": [
        {
            "content": "회의 승인 후 프로젝트 지식 인덱스를 생성한다.",
            "evidence_refs": [{"segment_id": "seg-1", "quote": "프로젝트 지식으로 축적"}],
            "confidence": 0.93,
        }
    ],
    "action_items": [
        {
            "title": "지식 인덱스 smoke 검증",
            "assignee": None,
            "due_date": "2026-06-30",
            "target_module": "task",
            "evidence": "프로젝트 지식으로 축적",
            "evidence_refs": [{"segment_id": "seg-1"}],
            "priority": "medium",
            "confidence": 0.9,
            "task_conversion_policy": "manual_review_required",
            "task_conversion_status": "candidate",
        }
    ],
    "risks": [
        {
            "title": "지식 검색 누락 위험",
            "level": "medium",
            "evidence": "지식 인덱스가 없으면 회의 근거 추적이 어렵다.",
            "evidence_refs": [{"segment_id": "seg-1"}],
            "confidence": 0.88,
        }
    ],
    "required_resources": [
        {
            "name": "검색 인덱스 저장소",
            "resource_type": "software",
            "quantity": 1,
            "reason": "Project_ID 중심 지식 조회",
            "evidence_refs": [{"segment_id": "seg-1"}],
            "confidence": 0.86,
        }
    ],
    "requires_human_approval": True,
}

missing_auth = client.get(f"/projects/{project_id}/knowledge-items")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Knowledge Smoke",
                email=f"knowledge-{stamp}@local.test",
                role="pm",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Knowledge Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
            VALUES (%s, %s, %s, 'review_required', %s)
            """,
            (meeting_id, project_id, "Knowledge Smoke Meeting", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json)
            VALUES (%s, %s, 'draft', 'knowledge-smoke', %s, %s)
            """,
            (analysis_id, meeting_id, result_json["summary"], Jsonb(result_json)),
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

approval = client.post(
    f"/approvals/meeting-analyses/{analysis_id}/approve",
    headers=headers,
)
assert approval.status_code == 200, approval.text
approval_body = approval.json()
assert approval_body["created_knowledge_items"] == 5, approval_body

knowledge = client.get(f"/projects/{project_id}/knowledge-items", headers=headers)
assert knowledge.status_code == 200, knowledge.text
knowledge_rows = knowledge.json()
assert len(knowledge_rows) == 5, knowledge_rows
assert {row["item_kind"] for row in knowledge_rows} == {
    "summary",
    "decision",
    "action_item",
    "risk",
    "required_resource",
}, knowledge_rows

decisions = client.get(
    f"/projects/{project_id}/knowledge-items?item_kind=decision",
    headers=headers,
)
assert decisions.status_code == 200, decisions.text
assert len(decisions.json()) == 1, decisions.json()

risk_search = client.get(
    f"/projects/{project_id}/knowledge-items",
    params={"q": "누락"},
    headers=headers,
)
assert risk_search.status_code == 200, risk_search.text
assert len(risk_search.json()) == 1, risk_search.json()
assert risk_search.json()[0]["item_kind"] == "risk", risk_search.json()

decision_search = client.get(
    f"/projects/{project_id}/knowledge-items",
    params={"item_kind": "decision", "q": "승인"},
    headers=headers,
)
assert decision_search.status_code == 200, decision_search.text
assert len(decision_search.json()) == 1, decision_search.json()
assert decision_search.json()[0]["item_kind"] == "decision", decision_search.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
detail_body = detail.json()
assert detail_body["dashboard"]["knowledge_items"] == 5, detail_body
assert len(detail_body["knowledge_items"]) == 5, detail_body["knowledge_items"]

dashboard = client.get("/dashboard/summary", headers=headers)
assert dashboard.status_code == 200, dashboard.text
assert dashboard.json()["knowledge_items"] >= 5, dashboard.json()

print(
    {
        "missing_auth": missing_auth.status_code,
        "approval_knowledge_items": approval_body["created_knowledge_items"],
        "knowledge_kinds": sorted(row["item_kind"] for row in knowledge_rows),
        "project_id": project_id,
        "risk_search_hits": len(risk_search.json()),
    }
)
PY

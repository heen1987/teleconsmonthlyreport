#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

cd backend

.venv/bin/python - <<'PY'
import time
import uuid
from datetime import date, timedelta

from fastapi.testclient import TestClient
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = f"{time.strftime('%H%M%S')}-{uuid.uuid4().hex[:6]}"
employee_no = f"ODR{stamp}"
password = f"odrpw{stamp}"
project_id = f"PRJ-ODR-{stamp}"
meeting_id = f"MTG-ODR-{stamp}"
analysis_id = f"ANL-ODR-{stamp}"
overdue_task_id = f"TSK-ODR-LATE-{stamp}"
closed_task_id = f"TSK-ODR-CLOSED-{stamp}"
future_task_id = f"TSK-ODR-FUTURE-{stamp}"

missing_auth = client.post("/tasks/overdue-risks")
assert missing_auth.status_code == 401, missing_auth.text

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "overdue task risk promotion smoke",
    "transcript_segments": [],
    "decisions": [],
    "action_items": [],
    "risks": [],
    "required_resources": [],
    "requires_human_approval": True,
}

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Overdue Risk Smoke",
                email=f"overdue-risk-{stamp}@local.test",
                role="pm",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Overdue Risk Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
            VALUES (%s, %s, %s, 'approved', %s)
            """,
            (meeting_id, project_id, "Overdue Risk Smoke Meeting", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json, approved_at)
            VALUES (%s, %s, 'approved', 'overdue-risk-smoke', %s, %s, now())
            """,
            (analysis_id, meeting_id, result_json["summary"], Jsonb(result_json)),
        )
        for task_id, title, due_date, status in [
            (overdue_task_id, "Overdue risk smoke task", date.today() - timedelta(days=8), "draft"),
            (closed_task_id, "Closed overdue task", date.today() - timedelta(days=3), "completed"),
            (future_task_id, "Future task", date.today() + timedelta(days=3), "draft"),
        ]:
            cursor.execute(
                """
                INSERT INTO tasks
                    (
                        task_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        assignee,
                        due_date,
                        priority,
                        status,
                        conversion_status
                    )
                VALUES (%s, %s, %s, %s, %s, '김희섭', %s, 'high', %s, 'draft')
                """,
                (task_id, project_id, meeting_id, analysis_id, title, due_date, status),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

promoted = client.post(f"/tasks/overdue-risks?project_id={project_id}", headers=headers)
assert promoted.status_code == 200, promoted.text
body = promoted.json()
assert body["scanned_overdue_tasks"] == 1, body
assert len(body["created_risks"]) == 1, body
created = body["created_risks"][0]
assert created["project_id"] == project_id, created
assert created["level"] == "high", created
assert created["status"] == "candidate", created
assert "Delayed task:" in created["title"], created

again = client.post(f"/tasks/overdue-risks?project_id={project_id}", headers=headers)
assert again.status_code == 200, again.text
assert len(again.json()["created_risks"]) == 0, again.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
dashboard = detail.json()["dashboard"]
assert dashboard["tasks_overdue"] == 1, dashboard
assert dashboard["risks_unresolved"] == 1, dashboard

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT count(*) AS risk_count
            FROM risks
            WHERE project_id = %s
              AND evidence_refs @> %s
            """,
            (project_id, Jsonb([{"source_type": "task_delay", "task_id": overdue_task_id}])),
        )
        risk_count = cursor.fetchone()["risk_count"]
        cursor.execute(
            """
            SELECT count(*) AS audit_count
            FROM audit_logs
            WHERE action_type = 'promote_overdue_task_to_risk'
              AND after_value @> %s
            """,
            (Jsonb({"task_id": overdue_task_id}),),
        )
        audit_count = cursor.fetchone()["audit_count"]

assert risk_count == 1, risk_count
assert audit_count == 1, audit_count

print(
    {
        "missing_auth": missing_auth.status_code,
        "created_risks": len(body["created_risks"]),
        "idempotent_created_risks": len(again.json()["created_risks"]),
        "project_id": project_id,
    }
)
PY

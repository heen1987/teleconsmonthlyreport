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
employee_no = f"DKPI{stamp}"
password = f"dkpipw{stamp}"
project_id = f"PRJ-DKPI-{stamp}"
meeting_id = f"MTG-DKPI-{stamp}"
analysis_id = f"ANL-DKPI-{stamp}"
demand_id = f"RDM-DKPI-{stamp}"
allocation_id = f"RAL-DKPI-{stamp}"
distribution_id = f"DST-DKPI-{stamp}"
risk_id = f"RSK-DKPI-{stamp}"
task_id = f"TSK-DKPI-{stamp}"

missing_auth = client.get("/dashboard/summary")
assert missing_auth.status_code == 401, missing_auth.text

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "dashboard attention KPI smoke",
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
                name="Dashboard KPI Smoke",
                email=f"dashboard-kpi-{stamp}@local.test",
                role="pm",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Dashboard KPI Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
            VALUES (%s, %s, %s, 'distribution_failed', %s)
            """,
            (meeting_id, project_id, "Dashboard KPI Smoke Meeting", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json, approved_at)
            VALUES (%s, %s, 'approved', 'dashboard-kpi-smoke', %s, %s, now())
            """,
            (analysis_id, meeting_id, result_json["summary"], Jsonb(result_json)),
        )
        cursor.execute(
            """
            INSERT INTO tasks
                (task_id, project_id, source_meeting_id, source_analysis_id, title, due_date, status)
            VALUES (%s, %s, %s, %s, 'Overdue dashboard smoke task', %s, 'draft')
            """,
            (task_id, project_id, meeting_id, analysis_id, date.today() - timedelta(days=1)),
        )
        cursor.execute(
            """
            INSERT INTO risks
                (risk_id, project_id, source_meeting_id, source_analysis_id, title, level, status)
            VALUES (%s, %s, %s, %s, 'Dashboard smoke unresolved risk', 'medium', 'candidate')
            """,
            (risk_id, project_id, meeting_id, analysis_id),
        )
        cursor.execute(
            """
            INSERT INTO resource_demands
                (demand_id, project_id, name, resource_type, needed_from, needed_to, demand_status)
            VALUES (%s, %s, 'Dashboard smoke room', 'room', %s, %s, 'conflict')
            """,
            (demand_id, project_id, date.today(), date.today() + timedelta(days=1)),
        )
        cursor.execute(
            """
            INSERT INTO resource_allocations
                (
                    allocation_id,
                    demand_id,
                    project_id,
                    resource_name,
                    resource_type,
                    allocation_type,
                    starts_on,
                    ends_on,
                    status,
                    conflict_reason,
                    created_by
                )
            VALUES (%s, %s, %s, 'Dashboard Smoke Room', 'room', 'reservation', %s, %s, 'conflict', 'overlaps:smoke', %s)
            """,
            (
                allocation_id,
                demand_id,
                project_id,
                date.today(),
                date.today() + timedelta(days=1),
                user["user_id"],
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
            VALUES (%s, %s, %s, '[AI-PMS] Dashboard KPI Smoke', 'body', %s, 'retry_wait', 'smtp', %s, 1, 'dashboard smoke retry', now())
            """,
            (
                distribution_id,
                meeting_id,
                analysis_id,
                Jsonb([{"email": f"dashboard-kpi-{stamp}@local.test"}]),
                user["user_id"],
            ),
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

dashboard = client.get("/dashboard/summary", headers=headers)
assert dashboard.status_code == 200, dashboard.text
body = dashboard.json()
assert body["overdue_tasks"] >= 1, body
assert body["unresolved_risks"] >= 1, body
assert body["resource_conflicts"] >= 1, body
assert body["distribution_failures"] >= 1, body

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
project_dashboard = detail.json()["dashboard"]
assert project_dashboard["tasks_overdue"] == 1, project_dashboard
assert project_dashboard["risks_unresolved"] == 1, project_dashboard
assert project_dashboard["resource_conflicts"] == 1, project_dashboard
assert project_dashboard["distribution_failures"] == 1, project_dashboard

print(
    {
        "missing_auth": missing_auth.status_code,
        "overdue_tasks": body["overdue_tasks"],
        "unresolved_risks": body["unresolved_risks"],
        "resource_conflicts": body["resource_conflicts"],
        "distribution_failures": body["distribution_failures"],
        "project_id": project_id,
    }
)
PY

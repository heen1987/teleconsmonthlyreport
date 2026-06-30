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
employee_no = f"UDR{stamp}"
password = f"udrpw{stamp}"
project_id = f"PRJ-UDR-{stamp}"
overdue_demand_id = f"RDM-UDR-LATE-{stamp}"
future_demand_id = f"RDM-UDR-FUTURE-{stamp}"
assigned_demand_id = f"RDM-UDR-ASSIGNED-{stamp}"

missing_auth = client.post("/resources/demands/unassigned-risks")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Unassigned Resource Risk Smoke",
                email=f"unassigned-resource-risk-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Unassigned Resource Risk Smoke Project", user["user_id"]),
        )
        for demand_id, name, needed_from, status in [
            (overdue_demand_id, "미배정 분석 장비", date.today() - timedelta(days=2), "candidate"),
            (future_demand_id, "미래 회의실", date.today() + timedelta(days=7), "candidate"),
            (assigned_demand_id, "이미 배정된 장비", date.today() - timedelta(days=3), "assigned"),
        ]:
            cursor.execute(
                """
                INSERT INTO resource_demands
                    (
                        demand_id,
                        project_id,
                        name,
                        resource_type,
                        quantity,
                        needed_from,
                        needed_to,
                        reason,
                        demand_status
                    )
                VALUES (%s, %s, %s, 'equipment', 1, %s, %s, %s, %s)
                """,
                (
                    demand_id,
                    project_id,
                    name,
                    needed_from,
                    needed_from + timedelta(days=1),
                    "미배정 자원 수요 리스크 승격 smoke 검증",
                    status,
                ),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

promoted = client.post(f"/resources/demands/unassigned-risks?project_id={project_id}", headers=headers)
assert promoted.status_code == 200, promoted.text
body = promoted.json()
assert body["scanned_demands"] == 1, body
assert body["due_within_days"] == 0, body
assert len(body["created_risks"]) == 1, body
created = body["created_risks"][0]
assert created["project_id"] == project_id, created
assert created["level"] == "high", created
assert created["status"] == "candidate", created
assert "Unassigned resource demand:" in created["title"], created

again = client.post(f"/resources/demands/unassigned-risks?project_id={project_id}", headers=headers)
assert again.status_code == 200, again.text
assert again.json()["scanned_demands"] == 1, again.json()
assert len(again.json()["created_risks"]) == 0, again.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
dashboard = detail.json()["dashboard"]
assert dashboard["resource_demands_candidate"] == 2, dashboard
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
            (project_id, Jsonb([{"source_type": "resource_unassigned", "demand_id": overdue_demand_id}])),
        )
        risk_count = cursor.fetchone()["risk_count"]
        cursor.execute(
            """
            SELECT count(*) AS audit_count
            FROM audit_logs
            WHERE action_type = 'promote_unassigned_resource_demand_to_risk'
              AND after_value @> %s
            """,
            (Jsonb({"demand_id": overdue_demand_id}),),
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
        "demand_id": overdue_demand_id,
    }
)
PY

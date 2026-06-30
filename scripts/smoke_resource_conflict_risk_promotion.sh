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
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = f"{time.strftime('%H%M%S')}-{uuid.uuid4().hex[:6]}"
employee_no = f"RCR{stamp}"
password = f"rcrpw{stamp}"
project_id = f"PRJ-RCR-{stamp}"
demand_1 = f"RDM-RCR-1-{stamp}"
demand_2 = f"RDM-RCR-2-{stamp}"
resource_name = f"Room-Conflict-{stamp}"

missing_auth = client.post("/resources/allocations/conflict-risks")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Resource Conflict Risk Smoke",
                email=f"resource-conflict-risk-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Conflict Risk Smoke Project", user["user_id"]),
        )
        for demand_id, needed_from, needed_to in [
            (demand_1, "2026-07-01", "2026-07-03"),
            (demand_2, "2026-07-02", "2026-07-04"),
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
                VALUES (%s, %s, %s, 'room', 1, %s, %s, %s, 'candidate')
                """,
                (
                    demand_id,
                    project_id,
                    "회의실 예약",
                    needed_from,
                    needed_to,
                    "자원 충돌 리스크 승격 smoke 검증",
                ),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

first = client.post(
    f"/resources/demands/{demand_1}/allocations",
    headers=headers,
    json={"resource_name": resource_name, "allocation_type": "reservation"},
)
assert first.status_code == 200, first.text
first_body = first.json()
assert first_body["status"] == "proposed", first_body

conflict = client.post(
    f"/resources/demands/{demand_2}/allocations",
    headers=headers,
    json={"resource_name": resource_name, "allocation_type": "reservation"},
)
assert conflict.status_code == 200, conflict.text
conflict_body = conflict.json()
assert conflict_body["status"] == "conflict", conflict_body
assert conflict_body["conflict_reason"] == f"overlaps:{first_body['allocation_id']}", conflict_body

promoted = client.post(f"/resources/allocations/conflict-risks?project_id={project_id}", headers=headers)
assert promoted.status_code == 200, promoted.text
body = promoted.json()
assert body["scanned_conflicts"] == 1, body
assert len(body["created_risks"]) == 1, body
created = body["created_risks"][0]
assert created["project_id"] == project_id, created
assert created["status"] == "candidate", created
assert "Resource conflict:" in created["title"], created

again = client.post(f"/resources/allocations/conflict-risks?project_id={project_id}", headers=headers)
assert again.status_code == 200, again.text
assert again.json()["scanned_conflicts"] == 1, again.json()
assert len(again.json()["created_risks"]) == 0, again.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
dashboard = detail.json()["dashboard"]
assert dashboard["resource_conflicts"] == 1, dashboard
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
            (
                project_id,
                Jsonb([{"source_type": "resource_conflict", "allocation_id": conflict_body["allocation_id"]}]),
            ),
        )
        risk_count = cursor.fetchone()["risk_count"]
        cursor.execute(
            """
            SELECT count(*) AS audit_count
            FROM audit_logs
            WHERE action_type = 'promote_resource_conflict_to_risk'
              AND after_value @> %s
            """,
            (Jsonb({"allocation_id": conflict_body["allocation_id"]}),),
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
        "allocation_id": conflict_body["allocation_id"],
    }
)
PY

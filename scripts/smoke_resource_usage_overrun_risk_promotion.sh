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
employee_no = f"UOR{stamp}"
password = f"uorpw{stamp}"
project_id = f"PRJ-UOR-{stamp}"
demand_1 = f"RDM-UOR-OVER-{stamp}"
demand_2 = f"RDM-UOR-NORMAL-{stamp}"

missing_auth = client.post("/resources/usage/overrun-risks")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Resource Usage Overrun Smoke",
                email=f"resource-usage-overrun-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Usage Overrun Smoke Project", user["user_id"]),
        )
        for demand_id, name, day in [
            (demand_1, "초과 사용 회의실", "2026-09-01"),
            (demand_2, "정상 사용 회의실", "2026-09-02"),
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
                    name,
                    day,
                    day,
                    "사용실적 초과 리스크 승격 smoke 검증",
                ),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

profile = client.post(
    "/resources/profiles",
    headers=headers,
    json={
        "resource_name": f"Room-Overrun-{stamp}",
        "resource_type": "room",
        "capacity": 1,
        "unit": "hour",
        "location": "4F",
    },
)
assert profile.status_code == 200, profile.text
resource_id = profile.json()["resource_id"]

overrun_allocation = client.post(
    f"/resources/demands/{demand_1}/allocations",
    headers=headers,
    json={"resource_id": resource_id, "allocation_type": "reservation", "quantity": 1},
)
assert overrun_allocation.status_code == 200, overrun_allocation.text
overrun_allocation_body = overrun_allocation.json()
assert overrun_allocation_body["status"] == "proposed", overrun_allocation_body

normal_allocation = client.post(
    f"/resources/demands/{demand_2}/allocations",
    headers=headers,
    json={"resource_name": f"Room-Normal-{stamp}", "allocation_type": "reservation", "quantity": 2},
)
assert normal_allocation.status_code == 200, normal_allocation.text
normal_allocation_body = normal_allocation.json()
assert normal_allocation_body["status"] == "proposed", normal_allocation_body

overrun_usage = client.post(
    f"/resources/allocations/{overrun_allocation_body['allocation_id']}/usage",
    headers=headers,
    json={
        "usage_date": "2026-09-01",
        "quantity": 2.5,
        "unit": "hour",
        "cost_amount": 75000,
        "note": "회의실 초과 사용",
    },
)
assert overrun_usage.status_code == 200, overrun_usage.text
overrun_usage_body = overrun_usage.json()

normal_usage = client.post(
    f"/resources/allocations/{normal_allocation_body['allocation_id']}/usage",
    headers=headers,
    json={
        "usage_date": "2026-09-02",
        "quantity": 1.5,
        "unit": "hour",
        "cost_amount": 45000,
        "note": "회의실 정상 사용",
    },
)
assert normal_usage.status_code == 200, normal_usage.text

promoted = client.post(f"/resources/usage/overrun-risks?project_id={project_id}", headers=headers)
assert promoted.status_code == 200, promoted.text
body = promoted.json()
assert body["scanned_usage_entries"] == 1, body
assert body["threshold_ratio"] == 1.0, body
assert len(body["created_risks"]) == 1, body
created = body["created_risks"][0]
assert created["project_id"] == project_id, created
assert created["level"] == "high", created
assert created["status"] == "candidate", created
assert "Resource usage overrun:" in created["title"], created

again = client.post(f"/resources/usage/overrun-risks?project_id={project_id}", headers=headers)
assert again.status_code == 200, again.text
assert again.json()["scanned_usage_entries"] == 1, again.json()
assert len(again.json()["created_risks"]) == 0, again.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
dashboard = detail.json()["dashboard"]
assert dashboard["risks_unresolved"] == 1, dashboard

summary = client.get("/dashboard/summary", headers=headers)
assert summary.status_code == 200, summary.text
summary_body = summary.json()
assert summary_body["resource_usage_entries"] >= 2, summary_body

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
                Jsonb(
                    [
                        {
                            "source_type": "resource_usage_overrun",
                            "usage_id": overrun_usage_body["usage"]["usage_id"],
                        }
                    ]
                ),
            ),
        )
        risk_count = cursor.fetchone()["risk_count"]
        cursor.execute(
            """
            SELECT count(*) AS audit_count
            FROM audit_logs
            WHERE action_type = 'promote_resource_usage_overrun_to_risk'
              AND after_value @> %s
            """,
            (Jsonb({"usage_id": overrun_usage_body["usage"]["usage_id"]}),),
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
        "usage_id": overrun_usage_body["usage"]["usage_id"],
    }
)
PY

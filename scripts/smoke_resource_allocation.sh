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

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = f"{time.strftime('%H%M%S')}-{uuid.uuid4().hex[:6]}"
employee_no = f"RALL{stamp}"
password = f"rallpw{stamp}"
project_id = f"PRJ-RALL-{stamp}"
demand_1 = f"RDM-RALL-1-{stamp}"
demand_2 = f"RDM-RALL-2-{stamp}"
demand_3 = f"RDM-RALL-3-{stamp}"
resource_name = f"Room-A-{stamp}"


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Resource Allocation Smoke",
                email=f"resource-allocation-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Allocation Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'resource_manager')
            """,
            (project_id, user["user_id"]),
        )
        for demand_id, needed_from, needed_to in [
            (demand_1, "2026-07-01", "2026-07-03"),
            (demand_2, "2026-07-02", "2026-07-04"),
            (demand_3, "2026-07-10", "2026-07-11"),
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
                    "중복 예약 충돌 smoke 검증",
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
assert first_body["allocation_type"] == "reservation", first_body
assert first_body["starts_on"] == "2026-07-01", first_body

conflict = client.post(
    f"/resources/demands/{demand_2}/allocations",
    headers=headers,
    json={"resource_name": resource_name, "allocation_type": "reservation"},
)
assert conflict.status_code == 200, conflict.text
conflict_body = conflict.json()
assert conflict_body["status"] == "conflict", conflict_body
assert conflict_body["conflict_reason"] == f"overlaps:{first_body['allocation_id']}", conflict_body

non_overlap = client.post(
    f"/resources/demands/{demand_3}/allocations",
    headers=headers,
    json={"resource_name": resource_name, "allocation_type": "reservation"},
)
assert non_overlap.status_code == 200, non_overlap.text
assert non_overlap.json()["status"] == "proposed", non_overlap.text

confirmed = client.patch(
    f"/resources/allocations/{first_body['allocation_id']}/status",
    headers=headers,
    json={"status": "confirmed"},
)
assert confirmed.status_code == 200, confirmed.text
assert confirmed.json()["status"] == "confirmed", confirmed.text

blocked_conflict_confirm = client.patch(
    f"/resources/allocations/{conflict_body['allocation_id']}/status",
    headers=headers,
    json={"status": "confirmed"},
)
assert blocked_conflict_confirm.status_code == 409, blocked_conflict_confirm.text

listed = client.get(f"/resources/allocations?project_id={project_id}", headers=headers)
assert listed.status_code == 200, listed.text
listed_body = listed.json()
assert len(listed_body) == 3, listed_body

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT demand_id, demand_status
            FROM resource_demands
            WHERE demand_id IN (%s, %s, %s)
            ORDER BY demand_id
            """,
            (demand_1, demand_2, demand_3),
        )
        statuses = {row["demand_id"]: row["demand_status"] for row in cursor.fetchall()}

assert statuses[demand_1] == "reserved", statuses
assert statuses[demand_2] == "conflict", statuses
assert statuses[demand_3] == "reserved", statuses

print(
    {
        "first": first_body["status"],
        "conflict": conflict_body["conflict_reason"],
        "listed": len(listed_body),
        "confirmed": confirmed.json()["status"],
    }
)
PY

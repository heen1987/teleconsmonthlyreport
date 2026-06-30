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
employee_no = f"RPRO{stamp}"
password = f"rpropw{stamp}"
project_id = f"PRJ-RPRO-{stamp}"
demand_1 = f"RDM-RPRO-1-{stamp}"
demand_2 = f"RDM-RPRO-2-{stamp}"


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Resource Profile Smoke",
                email=f"resource-profile-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Profile Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'resource_manager')
            """,
            (project_id, user["user_id"]),
        )
        for demand_id, needed_from, needed_to in [
            (demand_1, "2026-08-01", "2026-08-02"),
            (demand_2, "2026-08-01", "2026-08-02"),
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
                    "Profile-based room reservation",
                    needed_from,
                    needed_to,
                    "Resource profile availability smoke verification",
                ),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

profile = client.post(
    "/resources/profiles",
    headers=headers,
    json={
        "resource_name": f"Room-A-{stamp}",
        "resource_type": "room",
        "capacity": 1,
        "unit": "room",
        "location": "3F",
    },
)
assert profile.status_code == 200, profile.text
profile_body = profile.json()
resource_id = profile_body["resource_id"]
assert profile_body["status"] == "active", profile_body
assert profile_body["resource_type"] == "room", profile_body

available_before = client.get(
    "/resources/profiles/availability?resource_type=room&starts_on=2026-08-01&ends_on=2026-08-02",
    headers=headers,
)
assert available_before.status_code == 200, available_before.text
profile_availability = [
    row for row in available_before.json() if row["resource_id"] == resource_id
]
assert profile_availability and profile_availability[0]["is_available"] is True, available_before.json()

allocation = client.post(
    f"/resources/demands/{demand_1}/allocations",
    headers=headers,
    json={"resource_id": resource_id, "allocation_type": "reservation"},
)
assert allocation.status_code == 200, allocation.text
allocation_body = allocation.json()
assert allocation_body["resource_id"] == resource_id, allocation_body
assert allocation_body["resource_name"] == profile_body["resource_name"], allocation_body
assert allocation_body["status"] == "proposed", allocation_body

available_after = client.get(
    "/resources/profiles/availability?resource_type=room&starts_on=2026-08-01&ends_on=2026-08-02",
    headers=headers,
)
assert available_after.status_code == 200, available_after.text
blocked = [row for row in available_after.json() if row["resource_id"] == resource_id][0]
assert blocked["is_available"] is False, blocked
assert blocked["blocking_allocation_id"] == allocation_body["allocation_id"], blocked

conflict = client.post(
    f"/resources/demands/{demand_2}/allocations",
    headers=headers,
    json={"resource_id": resource_id, "allocation_type": "reservation"},
)
assert conflict.status_code == 200, conflict.text
conflict_body = conflict.json()
assert conflict_body["status"] == "conflict", conflict_body
assert conflict_body["resource_id"] == resource_id, conflict_body

profiles = client.get("/resources/profiles?resource_type=room&status=active", headers=headers)
assert profiles.status_code == 200, profiles.text
assert any(row["resource_id"] == resource_id for row in profiles.json()), profiles.json()

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT demand_id, demand_status
            FROM resource_demands
            WHERE demand_id IN (%s, %s)
            """,
            (demand_1, demand_2),
        )
        statuses = {row["demand_id"]: row["demand_status"] for row in cursor.fetchall()}

assert statuses[demand_1] == "reserved", statuses
assert statuses[demand_2] == "conflict", statuses

print(
    {
        "profile": resource_id,
        "available_before": profile_availability[0]["is_available"],
        "available_after": blocked["is_available"],
        "conflict": conflict_body["conflict_reason"],
    }
)
PY

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
manager_employee_no = f"RCAL{stamp}"
viewer_employee_no = f"RCV{stamp}"
manager_password = f"rcalpw{stamp}"
viewer_password = f"rcvpw{stamp}"
project_id = f"PRJ-RCAL-{stamp}"


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        manager = create_user_record(
            cursor,
            UserCreate(
                employee_no=manager_employee_no,
                name="Resource Calendar Smoke",
                email=f"resource-calendar-{stamp}@local.test",
                role="resource_manager",
                initial_password=manager_password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        viewer = create_user_record(
            cursor,
            UserCreate(
                employee_no=viewer_employee_no,
                name="Resource Calendar Viewer Smoke",
                email=f"resource-calendar-viewer-{stamp}@local.test",
                role="viewer",
                initial_password=viewer_password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Calendar Smoke Project", manager["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'resource_manager'), (%s, %s, 'viewer')
            """,
            (project_id, manager["user_id"], project_id, viewer["user_id"]),
        )


manager_login = client.post("/users/login", json={"employee_no": manager_employee_no, "password": manager_password})
assert manager_login.status_code == 200, manager_login.text
manager_headers = {"Authorization": f"Bearer {manager_login.json()['access_token']}"}

viewer_login = client.post("/users/login", json={"employee_no": viewer_employee_no, "password": viewer_password})
assert viewer_login.status_code == 200, viewer_login.text
viewer_headers = {"Authorization": f"Bearer {viewer_login.json()['access_token']}"}

profile = client.post(
    "/resources/profiles",
    headers=manager_headers,
    json={
        "resource_name": f"Room-Calendar-{stamp}",
        "resource_type": "room",
        "capacity": 1,
        "unit": "room",
        "location": "3F",
    },
)
assert profile.status_code == 200, profile.text
resource_id = profile.json()["resource_id"]

before = client.get(
    "/resources/profiles/availability?starts_on=2026-10-01&ends_on=2026-10-01",
    headers=manager_headers,
)
assert before.status_code == 200, before.text
before_row = next(row for row in before.json() if row["resource_id"] == resource_id)
assert before_row["is_available"] is True, before_row
assert before_row["blocking_calendar_block_id"] is None, before_row

blocked_viewer = client.post(
    f"/resources/profiles/{resource_id}/calendar-blocks",
    headers=viewer_headers,
    json={
        "project_id": project_id,
        "starts_on": "2026-10-02",
        "ends_on": "2026-10-03",
        "block_type": "maintenance",
        "reason": "viewer should not create calendar blocks",
    },
)
assert blocked_viewer.status_code == 403, blocked_viewer.text

invalid = client.post(
    f"/resources/profiles/{resource_id}/calendar-blocks",
    headers=manager_headers,
    json={
        "starts_on": "2026-10-04",
        "ends_on": "2026-10-03",
        "block_type": "blackout",
    },
)
assert invalid.status_code == 422, invalid.text

block = client.post(
    f"/resources/profiles/{resource_id}/calendar-blocks",
    headers=manager_headers,
    json={
        "project_id": project_id,
        "starts_on": "2026-10-02",
        "ends_on": "2026-10-03",
        "block_type": "maintenance",
        "reason": "정기 점검",
    },
)
assert block.status_code == 200, block.text
block_body = block.json()
assert block_body["resource_id"] == resource_id, block_body
assert block_body["block_type"] == "maintenance", block_body

blocks = client.get(f"/resources/profiles/{resource_id}/calendar-blocks", headers=manager_headers)
assert blocks.status_code == 200, blocks.text
assert any(row["block_id"] == block_body["block_id"] for row in blocks.json()), blocks.json()

during = client.get(
    "/resources/profiles/availability?starts_on=2026-10-02&ends_on=2026-10-02",
    headers=manager_headers,
)
assert during.status_code == 200, during.text
during_row = next(row for row in during.json() if row["resource_id"] == resource_id)
assert during_row["is_available"] is False, during_row
assert during_row["blocking_calendar_block_id"] == block_body["block_id"], during_row

after = client.get(
    "/resources/profiles/availability?starts_on=2026-10-05&ends_on=2026-10-05",
    headers=manager_headers,
)
assert after.status_code == 200, after.text
after_row = next(row for row in after.json() if row["resource_id"] == resource_id)
assert after_row["is_available"] is True, after_row
assert after_row["blocking_calendar_block_id"] is None, after_row

print(
    {
        "resource": resource_id,
        "calendar_block": block_body["block_id"],
        "blocked_viewer": blocked_viewer.status_code,
        "invalid_window": invalid.status_code,
        "during_available": during_row["is_available"],
        "after_available": after_row["is_available"],
    }
)
PY

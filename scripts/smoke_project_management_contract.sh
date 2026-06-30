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

from app.db.session import get_connection
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = str(time.time_ns())
employee_no = f"PMC{stamp[-9:]}"
initial_password = "1234"
active_password = f"pw{stamp[-8:]}"
email = f"project-management-{stamp}@local.test"

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Project Management Contract Smoke",
                email=email,
                role="pm",
                initial_password=initial_password,
            ),
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": initial_password})
assert login.status_code == 200, login.text
initial_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

changed = client.post(
    "/users/password/change",
    headers=initial_headers,
    json={
        "employee_no": employee_no,
        "current_password": initial_password,
        "new_password": active_password,
    },
)
assert changed.status_code == 200, changed.text

active_login = client.post("/users/login", json={"employee_no": employee_no, "password": active_password})
assert active_login.status_code == 200, active_login.text
headers = {"Authorization": f"Bearer {active_login.json()['access_token']}"}

project_id = f"PJT-PMC-{stamp[-10:]}"
initial_description = "W-001 project management contract smoke initial description"
project = client.post(
    "/projects",
    headers=headers,
    json={
        "project_id": project_id,
        "name": "Project Management Contract Smoke",
        "description": initial_description,
        "pm_user_id": user["user_id"],
    },
)
assert project.status_code == 200, project.text
project_body = project.json()
assert project_body["project_id"] == project_id, project_body
assert project_body["description"] == initial_description, project_body
assert project_body["pm_user_id"] == user["user_id"], project_body

listed = client.get("/projects", headers=headers)
assert listed.status_code == 200, listed.text
listed_body = listed.json()
listed_project = next((row for row in listed_body if row["project_id"] == project_id), None)
assert listed_project is not None, listed_body
assert listed_project["description"] == initial_description, listed_project

single = client.get(f"/projects/{project_id}", headers=headers)
assert single.status_code == 200, single.text
assert single.json()["description"] == initial_description, single.json()

updated_description = "W-001 PUT updates project name and description"
updated = client.put(
    f"/projects/{project_id}",
    headers=headers,
    json={
        "name": "Project Management Contract Smoke Updated",
        "description": updated_description,
        "pm_user_id": None,
    },
)
assert updated.status_code == 200, updated.text
updated_body = updated.json()
assert updated_body["name"] == "Project Management Contract Smoke Updated", updated_body
assert updated_body["description"] == updated_description, updated_body
assert updated_body["pm_user_id"] is None, updated_body

noop = client.put(f"/projects/{project_id}", headers=headers, json={})
assert noop.status_code == 200, noop.text
assert noop.json()["description"] == updated_description, noop.json()

cleared = client.put(f"/projects/{project_id}", headers=headers, json={"description": None})
assert cleared.status_code == 200, cleared.text
assert cleared.json()["description"] is None, cleared.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
detail_body = detail.json()
assert detail_body["project_id"] == project_id, detail_body
assert detail_body["description"] is None, detail_body
assert detail_body["dashboard"]["project_id"] == project_id, detail_body

missing = client.put(
    f"/projects/{project_id}-missing",
    headers=headers,
    json={"name": "Should not exist"},
)
assert missing.status_code == 404, missing.text

print(
    {
        "project_id": project_id,
        "post_description": initial_description,
        "updated_name": updated_body["name"],
        "cleared_description": cleared.json()["description"],
        "missing_status": missing.status_code,
    }
)
PY

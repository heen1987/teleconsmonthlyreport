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
stamp = time.strftime("%H%M%S")
employee_no = f"GUARD{stamp}"
initial_password = "1234"
active_password = f"pw{stamp}"

public_create = client.post(
    "/users",
    json={
        "employee_no": employee_no,
        "name": "Guard Smoke",
        "email": f"guard{stamp}@local.test",
        "role": "pm",
        "initial_password": initial_password,
    },
)
assert public_create.status_code in {404, 405}, public_create.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Guard Smoke",
                email=f"guard{stamp}@local.test",
                role="pm",
                initial_password=initial_password,
            ),
        )

missing_auth = client.get("/projects")
assert missing_auth.status_code == 401, missing_auth.text

initial_login = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": initial_password},
)
assert initial_login.status_code == 200, initial_login.text
initial_token = initial_login.json()["access_token"]
initial_headers = {"Authorization": f"Bearer {initial_token}"}

password_required = client.get("/projects", headers=initial_headers)
assert password_required.status_code == 403, password_required.text
assert "Password change required" in password_required.text, password_required.text

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

revoked_after_change = client.get("/users/me", headers=initial_headers)
assert revoked_after_change.status_code == 401, revoked_after_change.text

active_login = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": active_password},
)
assert active_login.status_code == 200, active_login.text
active_token = active_login.json()["access_token"]
headers = {"Authorization": f"Bearer {active_token}"}

project_id = f"PJT-GUARD-{stamp}"
project = client.post(
    "/projects",
    headers=headers,
    json={
        "project_id": project_id,
        "name": "Protected API Guard Smoke",
        "pm_user_id": user["user_id"],
    },
)
assert project.status_code == 200, project.text

member = client.post(
    f"/projects/{project_id}/members",
    headers=headers,
    json={"user_id": user["user_id"], "project_role": "pm"},
)
assert member.status_code == 200, member.text

dashboard = client.get("/dashboard/summary", headers=headers)
assert dashboard.status_code == 200, dashboard.text

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
assert detail.json()["project_id"] == project_id, detail.json()

print(
    {
        "employee_no": employee_no,
        "missing_auth": missing_auth.status_code,
        "password_required": password_required.status_code,
        "active_project": project_id,
        "dashboard": "verified",
    }
)
PY

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
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
admin_no = f"ADM{stamp}"
admin_initial_password = "1234"
admin_active_password = f"adminpw{stamp}"
member_no = f"MAN{stamp}"
member_initial_password = "1234"
member_active_password = f"memberpw{stamp}"

public_create = client.post(
    "/users",
    json={
        "employee_no": member_no,
        "name": "Public Create",
        "email": f"public{stamp}@local.test",
        "role": "member",
        "initial_password": member_initial_password,
    },
)
assert public_create.status_code in {404, 405}, public_create.text

missing_admin_auth = client.post(
    "/admin/users",
    json={
        "employee_no": member_no,
        "name": "Managed User",
        "email": f"managed{stamp}@local.test",
        "role": "member",
        "initial_password": member_initial_password,
    },
)
assert missing_admin_auth.status_code == 401, missing_admin_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        create_user_record(
            cursor,
            UserCreate(
                employee_no=admin_no,
                name="Admin Smoke",
                email=f"admin{stamp}@local.test",
                role="admin",
                initial_password=admin_initial_password,
            ),
            status=AccountStatus.PASSWORD_CHANGE_REQUIRED.value,
        )

initial_admin_login = client.post(
    "/users/login",
    json={"employee_no": admin_no, "password": admin_initial_password},
)
assert initial_admin_login.status_code == 200, initial_admin_login.text
initial_admin_headers = {
    "Authorization": f"Bearer {initial_admin_login.json()['access_token']}"
}

password_gate = client.post(
    "/admin/users",
    headers=initial_admin_headers,
    json={
        "employee_no": member_no,
        "name": "Managed User",
        "email": f"managed{stamp}@local.test",
        "role": "member",
        "initial_password": member_initial_password,
    },
)
assert password_gate.status_code == 403, password_gate.text
assert "Password change required" in password_gate.text, password_gate.text

admin_change = client.post(
    "/users/password/change",
    headers=initial_admin_headers,
    json={
        "employee_no": admin_no,
        "current_password": admin_initial_password,
        "new_password": admin_active_password,
    },
)
assert admin_change.status_code == 200, admin_change.text

active_admin_login = client.post(
    "/users/login",
    json={"employee_no": admin_no, "password": admin_active_password},
)
assert active_admin_login.status_code == 200, active_admin_login.text
admin_headers = {"Authorization": f"Bearer {active_admin_login.json()['access_token']}"}

created = client.post(
    "/admin/users",
    headers=admin_headers,
    json={
        "employee_no": member_no,
        "name": "Managed User",
        "email": f"managed{stamp}@local.test",
        "role": "member",
        "initial_password": member_initial_password,
    },
)
assert created.status_code == 200, created.text
created_user = created.json()
assert created_user["employee_no"] == member_no, created_user
assert created_user["status"] == AccountStatus.PASSWORD_CHANGE_REQUIRED.value, created_user

duplicate = client.post(
    "/admin/users",
    headers=admin_headers,
    json={
        "employee_no": member_no,
        "name": "Duplicate Managed User",
        "role": "member",
        "initial_password": member_initial_password,
    },
)
assert duplicate.status_code == 409, duplicate.text

member_initial_login = client.post(
    "/users/login",
    json={"employee_no": member_no, "password": member_initial_password},
)
assert member_initial_login.status_code == 200, member_initial_login.text
member_initial_headers = {"Authorization": f"Bearer {member_initial_login.json()['access_token']}"}

member_change = client.post(
    "/users/password/change",
    headers=member_initial_headers,
    json={
        "employee_no": member_no,
        "current_password": member_initial_password,
        "new_password": member_active_password,
    },
)
assert member_change.status_code == 200, member_change.text

member_login = client.post(
    "/users/login",
    json={"employee_no": member_no, "password": member_active_password},
)
assert member_login.status_code == 200, member_login.text
member_headers = {"Authorization": f"Bearer {member_login.json()['access_token']}"}

non_admin_list = client.get("/admin/users", headers=member_headers)
assert non_admin_list.status_code == 403, non_admin_list.text
assert "Admin role required" in non_admin_list.text, non_admin_list.text

updated = client.put(
    f"/admin/users/{created_user['user_id']}",
    headers=admin_headers,
    json={
        "name": "Managed User Updated",
        "email": f"managed-updated{stamp}@local.test",
        "role": "viewer",
    },
)
assert updated.status_code == 200, updated.text
updated_user = updated.json()
assert updated_user["name"] == "Managed User Updated", updated_user
assert updated_user["email"] == f"managed-updated{stamp}@local.test", updated_user
assert updated_user["role"] == "viewer", updated_user

reset_password = f"resetpw{stamp}"
reset = client.post(
    f"/admin/users/{created_user['user_id']}/reset-password",
    headers=admin_headers,
    json={"new_password": reset_password, "force_password_change": True},
)
assert reset.status_code == 200, reset.text
reset_body = reset.json()
assert reset_body["user"]["employee_no"] == member_no, reset_body
assert reset_body["password_change_required"] is True, reset_body
assert reset_body["revoked_tokens"] >= 1, reset_body

revoked_member = client.get("/users/me", headers=member_headers)
assert revoked_member.status_code == 401, revoked_member.text

old_password_login = client.post(
    "/users/login",
    json={"employee_no": member_no, "password": member_active_password},
)
assert old_password_login.status_code == 401, old_password_login.text

reset_login = client.post(
    "/users/login",
    json={"employee_no": member_no, "password": reset_password},
)
assert reset_login.status_code == 200, reset_login.text
assert reset_login.json()["password_change_required"] is True, reset_login.text

users = client.get("/admin/users", headers=admin_headers)
assert users.status_code == 200, users.text
employee_numbers = {row["employee_no"] for row in users.json()}
assert admin_no in employee_numbers, employee_numbers
assert member_no in employee_numbers, employee_numbers

print(
    {
        "admin": admin_no,
        "created_user": member_no,
        "public_create": public_create.status_code,
        "missing_admin_auth": missing_admin_auth.status_code,
        "password_gate": password_gate.status_code,
        "duplicate": duplicate.status_code,
        "non_admin": non_admin_list.status_code,
        "update": updated_user["role"],
        "reset": reset_body["user"]["status"],
    }
)
PY

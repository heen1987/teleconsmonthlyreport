#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

cd backend

.venv/bin/python - <<'PY'
import time

from fastapi.testclient import TestClient

from app.db.session import get_connection
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
employee_no = f"AUTH{stamp}"
password = "1234"

public_create = client.post(
    "/users",
    json={
        "employee_no": employee_no,
        "name": "Auth Smoke",
        "email": f"auth{stamp}@local.test",
        "role": "member",
        "initial_password": password,
    },
)
assert public_create.status_code in {404, 405}, public_create.text

with get_connection() as connection:
    with connection.cursor() as cursor:
        create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Auth Smoke",
                email=f"auth{stamp}@local.test",
                role="member",
                initial_password=password,
            ),
        )

bad_login = client.post("/users/login", json={"employee_no": employee_no, "password": "wrong"})
assert bad_login.status_code == 401, bad_login.text

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
body = login.json()
assert body["token_type"] == "bearer", body
assert body["access_token"].startswith("aipms_"), body
assert not body["access_token"].startswith("demo-"), body
assert body["password_change_required"] is True, body
assert body["user"]["employee_no"] == employee_no, body

headers = {"Authorization": f"Bearer {body['access_token']}"}
me = client.get("/users/me", headers=headers)
assert me.status_code == 200, me.text
assert me.json()["employee_no"] == employee_no, me.json()

change_without_token = client.post(
    "/users/password/change",
    json={
        "employee_no": employee_no,
        "current_password": password,
        "new_password": "5678",
    },
)
assert change_without_token.status_code == 401, change_without_token.text

change_other_user = client.post(
    "/users/password/change",
    headers=headers,
    json={
        "employee_no": f"{employee_no}-OTHER",
        "current_password": password,
        "new_password": "5678",
    },
)
assert change_other_user.status_code == 403, change_other_user.text

missing_me = client.get("/users/me")
assert missing_me.status_code == 401, missing_me.text

logout = client.post("/users/logout", headers=headers)
assert logout.status_code == 200, logout.text

revoked_me = client.get("/users/me", headers=headers)
assert revoked_me.status_code == 401, revoked_me.text

print(
    {
        "employee_no": employee_no,
        "token_type": body["token_type"],
        "me": "verified",
        "logout": "revoked",
    }
)
PY

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
employee_no = f"RESET{stamp}"
email = f"reset{stamp}@local.test"
initial_password = "1234"
new_password = f"resetpw{stamp}"

with get_connection() as connection:
    with connection.cursor() as cursor:
        create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Password Reset Smoke",
                email=email,
                role="member",
                initial_password=initial_password,
            ),
        )

wrong_email = client.post(
    "/users/password-reset/request",
    json={"employee_no": employee_no, "email": f"wrong{stamp}@local.test"},
)
assert wrong_email.status_code == 404, wrong_email.text

request = client.post(
    "/users/password-reset/request",
    json={"employee_no": employee_no, "email": email},
)
assert request.status_code == 200, request.text
request_body = request.json()
assert request_body["delivery_status"] == "dev_token_returned", request_body
reset_token = request_body["reset_token"]
assert reset_token.startswith("aipms_reset_"), request_body

invalid_verify = client.get("/users/password-reset/verify", params={"token": "bad-token"})
assert invalid_verify.status_code == 404, invalid_verify.text

verify = client.get("/users/password-reset/verify", params={"token": reset_token})
assert verify.status_code == 200, verify.text
assert verify.json()["valid"] is True, verify.text
assert verify.json()["employee_no"] == employee_no, verify.text

login_before_reset = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": initial_password},
)
assert login_before_reset.status_code == 200, login_before_reset.text
headers = {"Authorization": f"Bearer {login_before_reset.json()['access_token']}"}

confirm = client.post(
    "/users/password-reset/confirm",
    json={"token": reset_token, "new_password": new_password},
)
assert confirm.status_code == 200, confirm.text
confirm_body = confirm.json()
assert confirm_body["employee_no"] == employee_no, confirm_body
assert confirm_body["status"] == "active", confirm_body
assert confirm_body["revoked_tokens"] >= 1, confirm_body

revoked_me = client.get("/users/me", headers=headers)
assert revoked_me.status_code == 401, revoked_me.text

reuse_confirm = client.post(
    "/users/password-reset/confirm",
    json={"token": reset_token, "new_password": f"unused{stamp}"},
)
assert reuse_confirm.status_code == 404, reuse_confirm.text

old_login = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": initial_password},
)
assert old_login.status_code == 401, old_login.text

new_login = client.post(
    "/users/login",
    json={"employee_no": employee_no, "password": new_password},
)
assert new_login.status_code == 200, new_login.text
assert new_login.json()["password_change_required"] is False, new_login.text

print(
    {
        "employee_no": employee_no,
        "wrong_email": wrong_email.status_code,
        "verify": "valid",
        "confirm": confirm_body["status"],
        "reuse": reuse_confirm.status_code,
        "revoked": confirm_body["revoked_tokens"],
    }
)
PY

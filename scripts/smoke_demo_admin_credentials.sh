#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/seed_demo_admin.sh >/dev/null

cd backend

.venv/bin/python - <<'PY'
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)

login = client.post(
    "/users/login",
    json={"employee_no": "admin", "password": "1234"},
)
assert login.status_code == 200, login.text
body = login.json()
assert body["user"]["employee_no"] == "admin", body
assert body["user"]["role"] == "admin", body
assert body["user"]["status"] == "active", body
assert body["password_change_required"] is False, body

headers = {"Authorization": f"Bearer {body['access_token']}"}

me = client.get("/users/me", headers=headers)
assert me.status_code == 200, me.text
assert me.json()["employee_no"] == "admin", me.text

admin_users = client.get("/admin/users", headers=headers)
assert admin_users.status_code == 200, admin_users.text
assert any(user["employee_no"] == "admin" for user in admin_users.json()), admin_users.text

logout = client.post("/users/logout", headers=headers)
assert logout.status_code == 200, logout.text

print({"admin": "admin", "password": "1234", "role": "admin", "status": "active"})
PY

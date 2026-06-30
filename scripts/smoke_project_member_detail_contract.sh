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
employee_no = f"PMD{stamp}"
initial_password = "1234"
active_password = f"pw{stamp}"
email = f"project-member-detail-{stamp}@local.test"

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Project Member Detail Smoke",
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

project_id = f"PJT-PMD-{stamp}"
project = client.post(
    "/projects",
    headers=headers,
    json={
        "project_id": project_id,
        "name": "Project Member Detail Contract Smoke",
        "pm_user_id": user["user_id"],
    },
)
assert project.status_code == 200, project.text

member = client.post(
    f"/projects/{project_id}/members",
    headers=headers,
    json={
        "user_id": user["user_id"],
        "project_role": "project_lead",
        "allocation_percent": 60.0,
        "planned_mm": 0.6,
        "staffing_note": "contract smoke",
        "annual_salary_krw": 70_000_000,
        "allocated_cost_krw": 3_500_000,
    },
)
assert member.status_code == 200, member.text
member_body = member.json()
assert member_body["email"] == email, member_body
assert member_body["user_role"] == "pm", member_body
assert member_body["project_role"] == "project_lead", member_body
assert member_body["allocation_percent"] == 60.0, member_body
assert member_body["planned_mm"] == 0.6, member_body
assert member_body["allocated_cost_krw"] == 3_500_000, member_body

listed = client.get(f"/projects/{project_id}/members", headers=headers)
assert listed.status_code == 200, listed.text
listed_members = listed.json()
assert len(listed_members) == 1, listed_members
assert listed_members[0]["email"] == email, listed_members
assert listed_members[0]["user_role"] == "pm", listed_members
assert listed_members[0]["project_role"] == "project_lead", listed_members

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
members = detail.json()["members"]
assert len(members) == 1, detail.json()
detail_member = members[0]
assert detail_member["email"] == email, detail_member
assert detail_member["user_role"] == "pm", detail_member
assert detail_member["project_role"] == "project_lead", detail_member
assert detail_member["allocation_percent"] == 60.0, detail_member
assert detail_member["planned_mm"] == 0.6, detail_member
assert detail_member["staffing_note"] == "contract smoke", detail_member
assert detail_member["annual_salary_krw"] == 70_000_000, detail_member
assert detail_member["allocated_cost_krw"] == 3_500_000, detail_member

deleted = client.delete(f"/projects/{project_id}/members/{user['user_id']}", headers=headers)
assert deleted.status_code == 204, deleted.text

delete_again = client.delete(f"/projects/{project_id}/members/{user['user_id']}", headers=headers)
assert delete_again.status_code == 404, delete_again.text

listed_after_delete = client.get(f"/projects/{project_id}/members", headers=headers)
assert listed_after_delete.status_code == 200, listed_after_delete.text
assert listed_after_delete.json() == [], listed_after_delete.json()

detail_after_delete = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail_after_delete.status_code == 200, detail_after_delete.text
assert detail_after_delete.json()["members"] == [], detail_after_delete.json()

print(
    {
        "project_id": project_id,
        "member_email": detail_member["email"],
        "project_role": detail_member["project_role"],
        "user_role": detail_member["user_role"],
        "allocation_percent": detail_member["allocation_percent"],
        "delete_status": deleted.status_code,
        "planned_mm": detail_member["planned_mm"],
    }
)
PY

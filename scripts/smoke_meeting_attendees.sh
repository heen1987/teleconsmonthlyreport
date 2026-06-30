#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

backend/.venv/bin/python - <<'PY'
import time
import sys
from pathlib import Path

import httpx
from psycopg.rows import dict_row

sys.path.insert(0, str(Path("backend").resolve()))

from app.db.session import get_connection
from app.schemas import UserCreate
from app.services.users import create_user_record


platform = "http://127.0.0.1:8000"
stamp = time.strftime("%H%M%S")
employee_no = f"ATT{stamp}"
initial_password = "1234"
active_password = f"pw{stamp}"
project_id = f"PJT-ATTENDEE-{stamp}"
meeting_id = f"MTG-ATTENDEE-{stamp}"


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="김희섭",
                email=f"attendee{stamp}@local.test",
                role="pm",
                initial_password=initial_password,
            ),
        )

with httpx.Client(timeout=60) as client:
    initial_login = client.post(
        f"{platform}/users/login",
        json={"employee_no": employee_no, "password": initial_password},
    ).raise_for_status().json()
    initial_headers = {"Authorization": f"Bearer {initial_login['access_token']}"}

    password_required = client.get(f"{platform}/projects", headers=initial_headers)
    if password_required.status_code != 403:
        raise RuntimeError(
            {
                "expected_password_change_required": 403,
                "actual_status": password_required.status_code,
                "body": password_required.text,
            }
        )

    client.post(
        f"{platform}/users/password/change",
        json={
            "employee_no": employee_no,
            "current_password": initial_password,
            "new_password": active_password,
        },
        headers=initial_headers,
    ).raise_for_status()

    active_login = client.post(
        f"{platform}/users/login",
        json={"employee_no": employee_no, "password": active_password},
    ).raise_for_status().json()
    headers = {"Authorization": f"Bearer {active_login['access_token']}"}

    missing_auth = client.get(f"{platform}/projects/{project_id}/detail")
    if missing_auth.status_code != 401:
        raise RuntimeError(
            {
                "expected_missing_auth": 401,
                "actual_status": missing_auth.status_code,
                "body": missing_auth.text,
            }
        )

    client.post(
        f"{platform}/projects",
        headers=headers,
        json={
            "project_id": project_id,
            "name": "Attendee smoke verification",
            "pm_user_id": user["user_id"],
        },
    ).raise_for_status()
    client.post(
        f"{platform}/projects/{project_id}/members",
        headers=headers,
        json={"user_id": user["user_id"], "project_role": "pm"},
    ).raise_for_status()
    detail = client.get(f"{platform}/projects/{project_id}/detail", headers=headers).raise_for_status().json()
    member_id = detail["members"][0]["user_id"]

    client.post(
        f"{platform}/meetings",
        headers=headers,
        json={
            "meeting_id": meeting_id,
            "project_id": project_id,
            "title": "Attendee smoke verification",
            "created_by": user["user_id"],
        },
    ).raise_for_status()

    rows = client.put(
        f"{platform}/meetings/{meeting_id}/attendees",
        headers=headers,
        json={
            "attendee_user_ids": [member_id],
            "actor_user_id": user["user_id"],
        },
    ).raise_for_status().json()
    assert len(rows) == 1, rows
    assert rows[0]["user_id"] == member_id, rows

    invalid = client.put(
        f"{platform}/meetings/{meeting_id}/attendees",
        headers=headers,
        json={
            "attendee_user_ids": ["USR-NOT-A-MEMBER"],
            "actor_user_id": user["user_id"],
        },
    )
    if invalid.status_code != 409:
        raise RuntimeError(
            {
                "expected_invalid_attendee": 409,
                "actual_status": invalid.status_code,
                "body": invalid.text,
            }
        )

print(
    {
        "meeting_id": meeting_id,
        "user_id": member_id,
        "missing_auth": missing_auth.status_code,
        "password_required": password_required.status_code,
        "saved_attendee": rows[0],
    }
)
PY

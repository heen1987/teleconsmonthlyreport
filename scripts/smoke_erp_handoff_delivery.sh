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

from app.core.config import settings
from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = f"{time.strftime('%H%M%S')}-{uuid.uuid4().hex[:6]}"
resource_employee_no = f"EHD-RM-{stamp}"
finance_employee_no = f"EHD-FIN-{stamp}"
resource_password = f"ehdrm{stamp}"
finance_password = f"ehdfin{stamp}"
project_id = f"PRJ-EHD-{stamp}"


def make_usage_cost(headers, resource_id, demand_id, amount):
    allocation = client.post(
        f"/resources/demands/{demand_id}/allocations",
        headers=headers,
        json={"resource_id": resource_id, "allocation_type": "reservation"},
    )
    assert allocation.status_code == 200, allocation.text
    allocation_id = allocation.json()["allocation_id"]

    usage = client.post(
        f"/resources/allocations/{allocation_id}/usage",
        headers=headers,
        json={
            "usage_date": "2026-10-01",
            "quantity": 1,
            "unit": "hour",
            "cost_amount": amount,
            "note": f"ERP handoff delivery smoke {amount}",
        },
    )
    assert usage.status_code == 200, usage.text
    return usage.json()["cost_candidate"]["cost_id"]


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        resource_user = create_user_record(
            cursor,
            UserCreate(
                employee_no=resource_employee_no,
                name="ERP Handoff Resource Smoke",
                email=f"ehd-rm-{stamp}@local.test",
                role="resource_manager",
                initial_password=resource_password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        finance_user = create_user_record(
            cursor,
            UserCreate(
                employee_no=finance_employee_no,
                name="ERP Handoff Finance Smoke",
                email=f"ehd-fin-{stamp}@local.test",
                role="finance",
                initial_password=finance_password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "ERP Handoff Delivery Smoke Project", resource_user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'resource_manager')
            """,
            (project_id, resource_user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'finance')
            """,
            (project_id, finance_user["user_id"]),
        )
        for index in range(1, 4):
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
                VALUES (%s, %s, %s, 'room', 1, '2026-10-01', '2026-10-01', %s, 'candidate')
                """,
                (
                    f"RDM-EHD-{index}-{stamp}",
                    project_id,
                    f"ERP delivery room {index}",
                    "ERP handoff delivery smoke verification",
                ),
            )

resource_login = client.post(
    "/users/login",
    json={"employee_no": resource_employee_no, "password": resource_password},
)
assert resource_login.status_code == 200, resource_login.text
resource_headers = {"Authorization": f"Bearer {resource_login.json()['access_token']}"}

finance_login = client.post(
    "/users/login",
    json={"employee_no": finance_employee_no, "password": finance_password},
)
assert finance_login.status_code == 200, finance_login.text
finance_headers = {"Authorization": f"Bearer {finance_login.json()['access_token']}"}

resource_ids = []
for index in range(1, 4):
    profile = client.post(
        "/resources/profiles",
        headers=resource_headers,
        json={
            "resource_name": f"ERP-Delivery-Room-{index}-{stamp}",
            "resource_type": "room",
            "capacity": 1,
            "unit": "room",
            "location": "ERP",
        },
    )
    assert profile.status_code == 200, profile.text
    resource_ids.append(profile.json()["resource_id"])

success_cost_id = make_usage_cost(resource_headers, resource_ids[0], f"RDM-EHD-1-{stamp}", 120000)
retry_cost_id = make_usage_cost(resource_headers, resource_ids[1], f"RDM-EHD-2-{stamp}", 130000)
due_cost_id = make_usage_cost(resource_headers, resource_ids[2], f"RDM-EHD-3-{stamp}", 140000)

for cost_id in (success_cost_id, retry_cost_id, due_cost_id):
    approved = client.patch(
        f"/resources/cost-candidates/{cost_id}/status",
        headers=finance_headers,
        json={"status": "approved", "review_note": "ERP delivery smoke approved"},
    )
    assert approved.status_code == 200, approved.text

success_handoff = client.post(
    f"/resources/cost-candidates/{success_cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp"},
)
assert success_handoff.status_code == 200, success_handoff.text
success_handoff_id = success_handoff.json()["handoff_id"]

blocked_send = client.post(
    f"/resources/cost-handoffs/{success_handoff_id}/send",
    headers=resource_headers,
)
assert blocked_send.status_code == 403, blocked_send.text

settings.erp_handoff_delivery_mode = "dev_log"
sent = client.post(
    f"/resources/cost-handoffs/{success_handoff_id}/send",
    headers=finance_headers,
)
assert sent.status_code == 200, sent.text
sent_body = sent.json()
assert sent_body["status"] == "sent", sent_body
assert sent_body["delivery_mode"] == "dev_log", sent_body
assert sent_body["attempt_count"] == 1, sent_body
assert sent_body["external_reference"].startswith("dev_log:"), sent_body
assert sent_body["last_error"] is None, sent_body
assert sent_body["response_payload"]["ledger_boundary"] == "external_erp_reference_only", sent_body

duplicate_send = client.post(
    f"/resources/cost-handoffs/{success_handoff_id}/send",
    headers=finance_headers,
)
assert duplicate_send.status_code == 409, duplicate_send.text

accepted = client.patch(
    f"/resources/cost-handoffs/{success_handoff_id}/status",
    headers=finance_headers,
    json={
        "status": "accepted",
        "external_reference": "ERP-ACCEPTED-SMOKE",
        "response_payload": {"erp_document_no": "ERP-ACCEPTED-SMOKE"},
        "response_note": "ERP accepted delivered payload",
    },
)
assert accepted.status_code == 200, accepted.text
assert accepted.json()["status"] == "accepted", accepted.json()

retry_handoff = client.post(
    f"/resources/cost-candidates/{retry_cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp"},
)
assert retry_handoff.status_code == 200, retry_handoff.text
retry_handoff_id = retry_handoff.json()["handoff_id"]

settings.erp_handoff_delivery_mode = "http"
settings.erp_handoff_endpoint_url = ""
settings.erp_handoff_retry_max_attempts = 3
settings.erp_handoff_retry_delay_seconds = 1

failed_once = client.post(
    f"/resources/cost-handoffs/{retry_handoff_id}/send",
    headers=finance_headers,
)
assert failed_once.status_code == 200, failed_once.text
failed_body = failed_once.json()
assert failed_body["status"] == "retry_wait", failed_body
assert failed_body["attempt_count"] == 1, failed_body
assert "ERP handoff endpoint URL is not configured" in failed_body["last_error"], failed_body
assert failed_body["next_retry_at"], failed_body

with get_connection() as connection:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE project_cost_handoffs
            SET next_retry_at = now() - interval '1 minute'
            WHERE handoff_id = %s
            """,
            (retry_handoff_id,),
        )

settings.erp_handoff_delivery_mode = "dev_log"
retried = client.post(
    "/resources/cost-handoffs/send-due",
    headers=finance_headers,
    json={"limit": 10},
)
assert retried.status_code == 200, retried.text
retried_rows = retried.json()
retried_ids = {row["handoff_id"] for row in retried_rows}
assert retry_handoff_id in retried_ids, retried_rows
retry_row = next(row for row in retried_rows if row["handoff_id"] == retry_handoff_id)
assert retry_row["status"] == "sent", retry_row
assert retry_row["attempt_count"] == 2, retry_row
assert retry_row["last_error"] is None, retry_row

due_handoff = client.post(
    f"/resources/cost-candidates/{due_cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp"},
)
assert due_handoff.status_code == 200, due_handoff.text
due_handoff_id = due_handoff.json()["handoff_id"]

worker_due = client.post(
    "/resources/cost-handoffs/send-due",
    headers=finance_headers,
    json={"limit": 10},
)
assert worker_due.status_code == 200, worker_due.text
worker_rows = worker_due.json()
assert any(row["handoff_id"] == due_handoff_id and row["status"] == "sent" for row in worker_rows), worker_rows

print(
    {
        "sent": sent_body["status"],
        "blocked_send": blocked_send.status_code,
        "duplicate_send": duplicate_send.status_code,
        "failed_once": failed_body["status"],
        "retried": retry_row["status"],
        "worker_due_count": len(worker_rows),
        "accepted": accepted.json()["status"],
    }
)
PY

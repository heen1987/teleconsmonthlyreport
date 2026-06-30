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
employee_no = f"RUSE{stamp}"
finance_employee_no = f"RFIN{stamp}"
password = f"rusepw{stamp}"
finance_password = f"rfinpw{stamp}"
project_id = f"PRJ-RUSE-{stamp}"
demand_1 = f"RDM-RUSE-1-{stamp}"
demand_2 = f"RDM-RUSE-2-{stamp}"


with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Resource Usage Smoke",
                email=f"resource-usage-{stamp}@local.test",
                role="resource_manager",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        finance_user = create_user_record(
            cursor,
            UserCreate(
                employee_no=finance_employee_no,
                name="Resource Usage Finance Smoke",
                email=f"resource-finance-{stamp}@local.test",
                role="finance",
                initial_password=finance_password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Resource Usage Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'resource_manager')
            """,
            (project_id, user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO project_members (project_id, user_id, project_role)
            VALUES (%s, %s, 'finance')
            """,
            (project_id, finance_user["user_id"]),
        )
        for demand_id in (demand_1, demand_2):
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
                VALUES (%s, %s, %s, 'room', 1, '2026-09-01', '2026-09-01', %s, 'candidate')
                """,
                (
                    demand_id,
                    project_id,
                    "회의실 사용 실적",
                    "Resource usage and cost smoke verification",
                ),
            )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

finance_login = client.post("/users/login", json={"employee_no": finance_employee_no, "password": finance_password})
assert finance_login.status_code == 200, finance_login.text
finance_headers = {"Authorization": f"Bearer {finance_login.json()['access_token']}"}

profile = client.post(
    "/resources/profiles",
    headers=headers,
    json={
        "resource_name": f"Room-Usage-{stamp}",
        "resource_type": "room",
        "capacity": 1,
        "unit": "room",
        "location": "4F",
    },
)
assert profile.status_code == 200, profile.text
resource_id = profile.json()["resource_id"]

allocation = client.post(
    f"/resources/demands/{demand_1}/allocations",
    headers=headers,
    json={"resource_id": resource_id, "allocation_type": "reservation"},
)
assert allocation.status_code == 200, allocation.text
allocation_body = allocation.json()
assert allocation_body["status"] == "proposed", allocation_body

usage = client.post(
    f"/resources/allocations/{allocation_body['allocation_id']}/usage",
    headers=headers,
    json={
        "usage_date": "2026-09-01",
        "quantity": 2.5,
        "unit": "hour",
        "cost_amount": 75000,
        "note": "회의실 2.5시간 사용",
    },
)
assert usage.status_code == 200, usage.text
usage_body = usage.json()
assert usage_body["usage"]["allocation_id"] == allocation_body["allocation_id"], usage_body
assert usage_body["usage"]["project_id"] == project_id, usage_body
assert usage_body["usage"]["quantity"] == 2.5, usage_body
assert usage_body["cost_candidate"]["amount"] == 75000.0, usage_body
assert usage_body["cost_candidate"]["source_id"] == usage_body["usage"]["usage_id"], usage_body

usage_list = client.get(f"/resources/usage?project_id={project_id}", headers=headers)
assert usage_list.status_code == 200, usage_list.text
assert any(row["usage_id"] == usage_body["usage"]["usage_id"] for row in usage_list.json()), usage_list.json()

costs = client.get(f"/resources/cost-candidates?project_id={project_id}&status=candidate", headers=headers)
assert costs.status_code == 200, costs.text
assert any(row["source_id"] == usage_body["usage"]["usage_id"] for row in costs.json()), costs.json()
cost_id = usage_body["cost_candidate"]["cost_id"]

blocked_review = client.patch(
    f"/resources/cost-candidates/{cost_id}/status",
    headers=headers,
    json={"status": "approved", "review_note": "resource manager should not approve"},
)
assert blocked_review.status_code == 403, blocked_review.text

candidate_handoff = client.post(
    f"/resources/cost-candidates/{cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp", "external_reference": "ERP-SHOULD-NOT-QUEUE"},
)
assert candidate_handoff.status_code == 409, candidate_handoff.text

approved = client.patch(
    f"/resources/cost-candidates/{cost_id}/status",
    headers=finance_headers,
    json={"status": "approved", "review_note": "finance smoke approved"},
)
assert approved.status_code == 200, approved.text
approved_body = approved.json()
assert approved_body["status"] == "approved", approved_body
assert approved_body["review_note"] == "finance smoke approved", approved_body
assert approved_body["reviewed_by"], approved_body
assert approved_body["reviewed_at"], approved_body

approved_costs = client.get(f"/resources/cost-candidates?project_id={project_id}&status=approved", headers=finance_headers)
assert approved_costs.status_code == 200, approved_costs.text
assert any(row["cost_id"] == cost_id for row in approved_costs.json()), approved_costs.json()

second_review = client.patch(
    f"/resources/cost-candidates/{cost_id}/status",
    headers=finance_headers,
    json={"status": "rejected", "review_note": "should not transition twice"},
)
assert second_review.status_code == 409, second_review.text

blocked_handoff = client.post(
    f"/resources/cost-candidates/{cost_id}/erp-handoff",
    headers=headers,
    json={"target_system": "external_erp", "external_reference": "ERP-BLOCKED"},
)
assert blocked_handoff.status_code == 403, blocked_handoff.text

handoff = client.post(
    f"/resources/cost-candidates/{cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp", "external_reference": f"ERP-{stamp}"},
)
assert handoff.status_code == 200, handoff.text
handoff_body = handoff.json()
assert handoff_body["cost_id"] == cost_id, handoff_body
assert handoff_body["project_id"] == project_id, handoff_body
assert handoff_body["status"] == "queued", handoff_body
assert handoff_body["external_reference"] == f"ERP-{stamp}", handoff_body
assert handoff_body["payload"]["amount"] == 75000.0, handoff_body
assert handoff_body["payload"]["ledger_boundary"] == "external_erp_reference_only", handoff_body

second_handoff = client.post(
    f"/resources/cost-candidates/{cost_id}/erp-handoff",
    headers=finance_headers,
    json={"target_system": "external_erp", "external_reference": f"ERP-{stamp}"},
)
assert second_handoff.status_code == 200, second_handoff.text
assert second_handoff.json()["handoff_id"] == handoff_body["handoff_id"], second_handoff.json()

blocked_reconciliation = client.patch(
    f"/resources/cost-handoffs/{handoff_body['handoff_id']}/status",
    headers=headers,
    json={
        "status": "accepted",
        "external_reference": f"ERP-{stamp}",
        "response_payload": {"erp_document_no": f"DOC-{stamp}"},
        "response_note": "resource manager should not reconcile",
    },
)
assert blocked_reconciliation.status_code == 403, blocked_reconciliation.text

accepted_handoff = client.patch(
    f"/resources/cost-handoffs/{handoff_body['handoff_id']}/status",
    headers=finance_headers,
    json={
        "status": "accepted",
        "external_reference": f"ERP-{stamp}-ACCEPTED",
        "response_payload": {"erp_document_no": f"DOC-{stamp}", "accepted": True},
        "response_note": "ERP accepted smoke payload",
    },
)
assert accepted_handoff.status_code == 200, accepted_handoff.text
accepted_body = accepted_handoff.json()
assert accepted_body["status"] == "accepted", accepted_body
assert accepted_body["external_reference"] == f"ERP-{stamp}-ACCEPTED", accepted_body
assert accepted_body["completed_at"], accepted_body
assert accepted_body["response_payload"]["erp_document_no"] == f"DOC-{stamp}", accepted_body
assert accepted_body["response_note"] == "ERP accepted smoke payload", accepted_body
assert accepted_body["response_received_by"], accepted_body

second_reconciliation = client.patch(
    f"/resources/cost-handoffs/{handoff_body['handoff_id']}/status",
    headers=finance_headers,
    json={
        "status": "failed",
        "response_payload": {"accepted": False},
        "response_note": "should not reconcile twice",
    },
)
assert second_reconciliation.status_code == 409, second_reconciliation.text

handoffs = client.get(f"/resources/cost-handoffs?project_id={project_id}&status=queued", headers=finance_headers)
assert handoffs.status_code == 200, handoffs.text
assert not any(row["handoff_id"] == handoff_body["handoff_id"] for row in handoffs.json()), handoffs.json()

accepted_handoffs = client.get(f"/resources/cost-handoffs?project_id={project_id}&status=accepted", headers=finance_headers)
assert accepted_handoffs.status_code == 200, accepted_handoffs.text
assert any(row["handoff_id"] == handoff_body["handoff_id"] for row in accepted_handoffs.json()), accepted_handoffs.json()

conflict = client.post(
    f"/resources/demands/{demand_2}/allocations",
    headers=headers,
    json={"resource_id": resource_id, "allocation_type": "reservation"},
)
assert conflict.status_code == 200, conflict.text
assert conflict.json()["status"] == "conflict", conflict.text

blocked_usage = client.post(
    f"/resources/allocations/{conflict.json()['allocation_id']}/usage",
    headers=headers,
    json={
        "usage_date": "2026-09-01",
        "quantity": 1,
        "unit": "hour",
        "cost_amount": 10000,
    },
)
assert blocked_usage.status_code == 409, blocked_usage.text

print(
    {
        "usage": usage_body["usage"]["usage_id"],
        "cost": cost_id,
        "cost_review": approved_body["status"],
        "handoff": handoff_body["handoff_id"],
        "handoff_status": accepted_body["status"],
        "candidate_handoff": candidate_handoff.status_code,
        "blocked_handoff": blocked_handoff.status_code,
        "blocked_reconciliation": blocked_reconciliation.status_code,
        "second_reconciliation": second_reconciliation.status_code,
        "blocked_resource_manager_review": blocked_review.status_code,
        "second_review": second_review.status_code,
        "blocked_conflict_usage": blocked_usage.status_code,
    }
)
PY

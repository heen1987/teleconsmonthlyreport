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
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus, MinutesStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = time.strftime("%H%M%S")
employee_no = f"OQS{stamp}"
password = f"oqspw{stamp}"
project_id = f"PRJ-OQS-{stamp}"
meeting_id = f"MTG-OQS-{stamp}"
analysis_id = f"ANL-OQS-{stamp}"
distribution_id = f"DST-OQS-{stamp}"
cost_id = f"CST-OQS-{stamp}"
handoff_id = f"PCH-OQS-{stamp}"

result_json = {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "operation queue smoke",
    "transcript_segments": [],
    "decisions": [],
    "action_items": [],
    "risks": [],
    "required_resources": [],
    "requires_human_approval": True,
}

missing_auth = client.get("/operations/queue-status")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Operation Queue Smoke",
                email=f"operation-queue-{stamp}@local.test",
                role="finance",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Operation Queue Smoke Project", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meetings (meeting_id, project_id, title, status, created_by)
            VALUES (%s, %s, %s, 'distribution_failed', %s)
            """,
            (meeting_id, project_id, "Operation Queue Smoke Meeting", user["user_id"]),
        )
        cursor.execute(
            """
            INSERT INTO meeting_analyses
                (analysis_id, meeting_id, status, model_name, summary, result_json, approved_at)
            VALUES (%s, %s, %s, 'operation-queue-smoke', %s, %s, now())
            """,
            (
                analysis_id,
                meeting_id,
                MinutesStatus.APPROVED.value,
                result_json["summary"],
                Jsonb(result_json),
            ),
        )
        cursor.execute(
            """
            INSERT INTO email_distributions
                (
                    distribution_id,
                    meeting_id,
                    analysis_id,
                    subject,
                    body,
                    recipients,
                    status,
                    delivery_mode,
                    requested_by,
                    attempt_count,
                    last_error,
                    next_retry_at
                )
            VALUES (%s, %s, %s, '[AI-PMS] Queue Smoke', 'body', %s, 'retry_wait', 'smtp', %s, 1, %s, now() - interval '1 minute')
            """,
            (
                distribution_id,
                meeting_id,
                analysis_id,
                Jsonb([{"email": f"operation-queue-{stamp}@local.test"}]),
                user["user_id"],
                "SMTP smoke retry",
            ),
        )
        cursor.execute(
            """
            INSERT INTO project_cost_candidates
                (
                    cost_id,
                    project_id,
                    source_type,
                    source_id,
                    cost_type,
                    amount,
                    currency,
                    status,
                    description,
                    created_by,
                    reviewed_by,
                    reviewed_at
                )
            VALUES (%s, %s, 'operation_queue_smoke', %s, 'resource_usage', 1000, 'KRW', 'approved', %s, %s, %s, now())
            """,
            (
                cost_id,
                project_id,
                f"SRC-OQS-{stamp}",
                "operation queue smoke cost",
                user["user_id"],
                user["user_id"],
            ),
        )
        cursor.execute(
            """
            INSERT INTO project_cost_handoffs
                (
                    handoff_id,
                    cost_id,
                    project_id,
                    target_system,
                    payload,
                    status,
                    requested_by,
                    delivery_mode,
                    attempt_count,
                    last_error,
                    next_retry_at
                )
            VALUES (%s, %s, %s, 'external_erp', %s, 'retry_wait', %s, 'http', 1, %s, now() - interval '1 minute')
            """,
            (
                handoff_id,
                cost_id,
                project_id,
                Jsonb({"project_id": project_id, "ledger_boundary": "external_erp_reference_only"}),
                user["user_id"],
                "ERP smoke retry",
            ),
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

status = client.get("/operations/queue-status", headers=headers)
assert status.status_code == 200, status.text
body = status.json()
assert body["email_distributions"]["status_counts"]["retry_wait"] >= 1, body
assert body["email_distributions"]["retry_due"] >= 1, body
assert body["email_distributions"]["attention_count"] >= 1, body
assert body["email_distributions"]["last_error"], body
assert body["erp_handoffs"]["status_counts"]["retry_wait"] >= 1, body
assert body["erp_handoffs"]["retry_due"] >= 1, body
assert body["erp_handoffs"]["attention_count"] >= 1, body
assert body["erp_handoffs"]["last_error"], body

email_retry = client.post("/distributions/retry-due", headers=headers, json={"limit": 100})
assert email_retry.status_code == 200, email_retry.text
email_retry_rows = email_retry.json()
assert any(
    row["distribution_id"] == distribution_id and row["status"] == "sent"
    for row in email_retry_rows
), email_retry_rows

erp_send_due = client.post("/resources/cost-handoffs/send-due", headers=headers, json={"limit": 100})
assert erp_send_due.status_code == 200, erp_send_due.text
erp_send_due_rows = erp_send_due.json()
assert any(
    row["handoff_id"] == handoff_id and row["status"] == "sent"
    for row in erp_send_due_rows
), erp_send_due_rows

print(
    {
        "missing_auth": missing_auth.status_code,
        "email_retry_due": body["email_distributions"]["retry_due"],
        "email_retry_processed": len(email_retry_rows),
        "erp_retry_due": body["erp_handoffs"]["retry_due"],
        "erp_send_due_processed": len(erp_send_due_rows),
        "generated_at": body["generated_at"],
    }
)
PY

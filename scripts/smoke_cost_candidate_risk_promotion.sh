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
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.main import app
from app.schemas import UserCreate
from app.services.users import create_user_record


client = TestClient(app)
stamp = f"{time.strftime('%H%M%S')}-{uuid.uuid4().hex[:6]}"
employee_no = f"CCR{stamp}"
password = f"ccrpw{stamp}"
project_id = f"PRJ-CCR-{stamp}"
high_cost_id = f"CST-CCR-HIGH-{stamp}"
low_cost_id = f"CST-CCR-LOW-{stamp}"
usd_cost_id = f"CST-CCR-USD-{stamp}"

missing_auth = client.post("/resources/cost-candidates/overrun-risks")
assert missing_auth.status_code == 401, missing_auth.text

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=employee_no,
                name="Cost Risk Smoke",
                email=f"cost-risk-{stamp}@local.test",
                role="finance",
                initial_password=password,
            ),
            status=AccountStatus.ACTIVE.value,
        )
        cursor.execute(
            "INSERT INTO projects (project_id, name, pm_user_id) VALUES (%s, %s, %s)",
            (project_id, "Cost Risk Smoke Project", user["user_id"]),
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
                    created_by
                )
            VALUES
                (%s, %s, 'resource_usage', %s, 'resource_usage', 2500000, 'KRW', 'candidate', '고가 GPU 사용', %s),
                (%s, %s, 'resource_usage', %s, 'resource_usage', 500000, 'KRW', 'candidate', '소액 회의실 사용', %s),
                (%s, %s, 'resource_usage', %s, 'resource_usage', 2500000, 'USD', 'candidate', '통화 불일치 비용', %s)
            """,
            (
                high_cost_id,
                project_id,
                f"USG-CCR-HIGH-{stamp}",
                user["user_id"],
                low_cost_id,
                project_id,
                f"USG-CCR-LOW-{stamp}",
                user["user_id"],
                usd_cost_id,
                project_id,
                f"USG-CCR-USD-{stamp}",
                user["user_id"],
            ),
        )

login = client.post("/users/login", json={"employee_no": employee_no, "password": password})
assert login.status_code == 200, login.text
headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

promoted = client.post(
    f"/resources/cost-candidates/overrun-risks?project_id={project_id}&threshold_amount=1000000&currency=KRW",
    headers=headers,
)
assert promoted.status_code == 200, promoted.text
body = promoted.json()
assert body["scanned_cost_candidates"] == 1, body
assert body["threshold_amount"] == 1000000.0, body
assert body["currency"] == "KRW", body
assert len(body["created_risks"]) == 1, body
created = body["created_risks"][0]
assert created["project_id"] == project_id, created
assert created["level"] == "high", created
assert created["status"] == "candidate", created
assert "Cost threshold exceeded:" in created["title"], created

again = client.post(
    f"/resources/cost-candidates/overrun-risks?project_id={project_id}&threshold_amount=1000000&currency=KRW",
    headers=headers,
)
assert again.status_code == 200, again.text
assert again.json()["scanned_cost_candidates"] == 1, again.json()
assert len(again.json()["created_risks"]) == 0, again.json()

detail = client.get(f"/projects/{project_id}/detail", headers=headers)
assert detail.status_code == 200, detail.text
dashboard = detail.json()["dashboard"]
assert dashboard["risks_unresolved"] == 1, dashboard

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT count(*) AS risk_count
            FROM risks
            WHERE project_id = %s
              AND evidence_refs @> %s
            """,
            (project_id, Jsonb([{"source_type": "cost_threshold", "cost_id": high_cost_id}])),
        )
        risk_count = cursor.fetchone()["risk_count"]
        cursor.execute(
            """
            SELECT count(*) AS audit_count
            FROM audit_logs
            WHERE action_type = 'promote_cost_candidate_to_risk'
              AND after_value @> %s
            """,
            (Jsonb({"cost_id": high_cost_id}),),
        )
        audit_count = cursor.fetchone()["audit_count"]

assert risk_count == 1, risk_count
assert audit_count == 1, audit_count

print(
    {
        "missing_auth": missing_auth.status_code,
        "created_risks": len(body["created_risks"]),
        "idempotent_created_risks": len(again.json()["created_risks"]),
        "project_id": project_id,
        "cost_id": high_cost_id,
    }
)
PY

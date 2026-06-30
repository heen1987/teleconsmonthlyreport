#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIMIT="${1:-10}"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

cd backend

.venv/bin/python - "$LIMIT" <<'PY'
import sys

from psycopg.rows import dict_row

from app.db.session import get_connection
from app.services.erp_handoff import deliver_project_cost_handoff


limit = max(1, min(int(sys.argv[1]), 100))

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT handoff_id,
                cost_id,
                project_id,
                target_system,
                payload,
                status,
                external_reference,
                requested_by,
                created_at,
                completed_at,
                response_payload,
                response_note,
                response_received_by,
                delivery_mode,
                attempt_count,
                last_error,
                next_retry_at,
                last_attempted_at
            FROM project_cost_handoffs
            WHERE status = 'queued'
               OR (
                    status = 'retry_wait'
                    AND next_retry_at IS NOT NULL
                    AND next_retry_at <= now()
                  )
            ORDER BY
                CASE WHEN status = 'queued' THEN 0 ELSE 1 END,
                COALESCE(next_retry_at, created_at) ASC,
                created_at ASC
            LIMIT %s
            FOR UPDATE SKIP LOCKED
            """,
            (limit,),
        )
        rows = cursor.fetchall()
        delivered = [deliver_project_cost_handoff(cursor, row) for row in rows]

print({"processed": len(delivered), "handoff_ids": [row["handoff_id"] for row in delivered]})
PY

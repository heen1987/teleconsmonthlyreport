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
from app.services.email_delivery import deliver_distribution


limit = max(1, min(int(sys.argv[1]), 100))

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            """
            SELECT distribution_id,
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
                next_retry_at,
                created_at,
                sent_at
            FROM email_distributions
            WHERE status IN ('retry_wait', 'partial_failed')
              AND next_retry_at IS NOT NULL
              AND next_retry_at <= now()
            ORDER BY next_retry_at ASC, created_at ASC
            LIMIT %s
            FOR UPDATE SKIP LOCKED
            """,
            (limit,),
        )
        rows = cursor.fetchall()
        delivered = [deliver_distribution(cursor, row) for row in rows]

print({"processed": len(delivered), "distribution_ids": [row["distribution_id"] for row in delivered]})
PY

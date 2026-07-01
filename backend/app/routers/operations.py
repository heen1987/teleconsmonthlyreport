from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends
from psycopg.rows import dict_row

from app.db.session import get_connection
from app.schemas import OperationQueueSectionOut, OperationQueueStatusOut
from app.services.auth_tokens import require_admin_user

router = APIRouter(prefix="/operations", tags=["operations"], dependencies=[Depends(require_admin_user)])

_ALLOWED_QUEUE_TABLES = frozenset({"email_distributions", "project_cost_handoffs"})


def _status_counts(cursor: Any, table_name: str) -> dict[str, int]:
    if table_name not in _ALLOWED_QUEUE_TABLES:
        raise ValueError(f"Unexpected table name for status_counts: {table_name!r}")
    cursor.execute(f"SELECT status, count(*)::int AS count FROM {table_name} GROUP BY status")
    return {row["status"]: row["count"] for row in cursor.fetchall()}


def _email_distribution_section(cursor: Any) -> OperationQueueSectionOut:
    cursor.execute(
        """
        SELECT
            count(*) FILTER (
                WHERE status IN ('retry_wait', 'partial_failed', 'failed')
                  AND next_retry_at IS NOT NULL
                  AND next_retry_at <= now()
            )::int AS retry_due,
            count(*) FILTER (
                WHERE status IN ('retry_wait', 'partial_failed', 'failed')
            )::int AS attention_count,
            max(created_at) AS latest_created_at,
            min(next_retry_at) FILTER (
                WHERE next_retry_at IS NOT NULL
                  AND next_retry_at > now()
            ) AS next_retry_at
        FROM email_distributions
        """
    )
    stats = cursor.fetchone()
    cursor.execute(
        """
        SELECT last_error
        FROM email_distributions
        WHERE last_error IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1
        """
    )
    error_row = cursor.fetchone()
    return OperationQueueSectionOut(
        status_counts=_status_counts(cursor, "email_distributions"),
        retry_due=stats["retry_due"],
        attention_count=stats["attention_count"],
        latest_created_at=stats["latest_created_at"],
        next_retry_at=stats["next_retry_at"],
        last_error=error_row["last_error"] if error_row else None,
    )


def _erp_handoff_section(cursor: Any) -> OperationQueueSectionOut:
    cursor.execute(
        """
        SELECT
            count(*) FILTER (
                WHERE status = 'retry_wait'
                  AND next_retry_at IS NOT NULL
                  AND next_retry_at <= now()
            )::int AS retry_due,
            count(*) FILTER (
                WHERE status IN ('queued', 'retry_wait', 'failed')
            )::int AS attention_count,
            max(created_at) AS latest_created_at,
            min(next_retry_at) FILTER (
                WHERE next_retry_at IS NOT NULL
                  AND next_retry_at > now()
            ) AS next_retry_at
        FROM project_cost_handoffs
        """
    )
    stats = cursor.fetchone()
    cursor.execute(
        """
        SELECT last_error
        FROM project_cost_handoffs
        WHERE last_error IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1
        """
    )
    error_row = cursor.fetchone()
    return OperationQueueSectionOut(
        status_counts=_status_counts(cursor, "project_cost_handoffs"),
        retry_due=stats["retry_due"],
        attention_count=stats["attention_count"],
        latest_created_at=stats["latest_created_at"],
        next_retry_at=stats["next_retry_at"],
        last_error=error_row["last_error"] if error_row else None,
    )


@router.get("/queue-status", response_model=OperationQueueStatusOut)
def get_operation_queue_status():
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            return OperationQueueStatusOut(
                generated_at=datetime.now(UTC),
                email_distributions=_email_distribution_section(cursor),
                erp_handoffs=_erp_handoff_section(cursor),
            )

from __future__ import annotations

import uuid
from typing import Any

import httpx
from psycopg.types.json import Jsonb

from app.core.config import settings

TERMINAL_HANDOFF_STATUSES = {"accepted", "rejected", "failed"}
SENDABLE_HANDOFF_STATUSES = {"queued", "retry_wait"}


def erp_handoff_delivery_mode() -> str:
    if settings.erp_handoff_delivery_mode == "http":
        return "http"
    return "dev_log"


def _provider_reference(handoff_id: str) -> str:
    return f"{erp_handoff_delivery_mode()}:{handoff_id}:{uuid.uuid4().hex[:8]}"


def _schedule_retry_sql(attempt_no: int) -> str:
    if attempt_no >= settings.erp_handoff_retry_max_attempts:
        return "NULL"
    return f"now() + interval '{max(settings.erp_handoff_retry_delay_seconds, 1)} seconds'"


def _send_to_erp(handoff: dict) -> tuple[str, dict[str, Any]]:
    mode = erp_handoff_delivery_mode()
    if mode == "dev_log":
        provider_reference = _provider_reference(handoff["handoff_id"])
        return provider_reference, {
            "mode": mode,
            "provider_reference": provider_reference,
            "target_system": handoff["target_system"],
            "ledger_boundary": "external_erp_reference_only",
        }

    if not settings.erp_handoff_endpoint_url:
        raise RuntimeError("ERP handoff endpoint URL is not configured")

    headers = {"Content-Type": "application/json"}
    if settings.erp_handoff_api_key:
        headers["Authorization"] = f"Bearer {settings.erp_handoff_api_key}"

    request_payload = {
        "handoff_id": handoff["handoff_id"],
        "cost_id": handoff["cost_id"],
        "project_id": handoff["project_id"],
        "target_system": handoff["target_system"],
        "payload": handoff["payload"],
        "external_reference": handoff["external_reference"],
    }
    response = httpx.post(
        settings.erp_handoff_endpoint_url,
        json=request_payload,
        headers=headers,
        timeout=settings.erp_handoff_timeout_seconds,
    )
    response.raise_for_status()

    try:
        loaded_payload = response.json()
        response_payload: dict[str, Any] = (
            loaded_payload if isinstance(loaded_payload, dict) else {"body": loaded_payload}
        )
    except ValueError:
        response_payload = {"body": response.text}

    provider_reference = (
        response_payload.get("external_reference")
        or response_payload.get("erp_document_no")
        or response_payload.get("document_no")
        or response_payload.get("id")
        or _provider_reference(handoff["handoff_id"])
    )
    return str(provider_reference), response_payload


def deliver_project_cost_handoff(cursor: Any, handoff: dict) -> dict:
    if handoff["status"] not in SENDABLE_HANDOFF_STATUSES:
        raise ValueError("Only queued or retry_wait cost handoff can be sent")

    attempt_no = int(handoff.get("attempt_count") or 0) + 1
    handoff_id = handoff["handoff_id"]
    mode = erp_handoff_delivery_mode()

    cursor.execute(
        """
        UPDATE project_cost_handoffs
        SET status = 'sending',
            delivery_mode = %s,
            attempt_count = %s,
            last_error = NULL,
            last_attempted_at = now()
        WHERE handoff_id = %s
        """,
        (mode, attempt_no, handoff_id),
    )

    try:
        provider_reference, response_payload = _send_to_erp(handoff)
    except Exception as exc:  # noqa: BLE001 - provider failures are captured for retry.
        error_message = str(exc)
        final_status = (
            "retry_wait"
            if attempt_no < settings.erp_handoff_retry_max_attempts
            else "failed"
        )
        next_retry_sql = _schedule_retry_sql(attempt_no)
        completed_at_sql = "now()" if final_status == "failed" else "NULL"
        cursor.execute(
            f"""
            UPDATE project_cost_handoffs
            SET status = %s,
                last_error = %s,
                next_retry_at = {next_retry_sql},
                completed_at = {completed_at_sql}
            WHERE handoff_id = %s
            RETURNING handoff_id,
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
            """,
            (final_status, error_message, handoff_id),
        )
        updated = cursor.fetchone()
        cursor.execute(
            """
            INSERT INTO audit_logs
                (actor_user_id, action_type, target_table, target_id, after_value)
            VALUES (%s, 'send_project_cost_handoff_failed', 'project_cost_handoffs', %s, %s)
            """,
            (
                handoff.get("requested_by") or "system",
                handoff_id,
                Jsonb(
                    {
                        "status": final_status,
                        "delivery_mode": mode,
                        "attempt_no": attempt_no,
                        "last_error": error_message,
                    }
                ),
            ),
        )
        return updated

    next_external_reference = provider_reference or handoff["external_reference"]
    cursor.execute(
        """
        UPDATE project_cost_handoffs
        SET status = 'sent',
            external_reference = %s,
            response_payload = %s,
            response_note = %s,
            last_error = NULL,
            next_retry_at = NULL
        WHERE handoff_id = %s
        RETURNING handoff_id,
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
        """,
        (
            next_external_reference,
            Jsonb(response_payload),
            "ERP handoff delivered; awaiting reconciliation",
            handoff_id,
        ),
    )
    updated = cursor.fetchone()
    cursor.execute(
        """
        INSERT INTO audit_logs
            (actor_user_id, action_type, target_table, target_id, after_value)
        VALUES (%s, 'send_project_cost_handoff', 'project_cost_handoffs', %s, %s)
        """,
        (
            handoff.get("requested_by") or "system",
            handoff_id,
            Jsonb(
                {
                    "status": "sent",
                    "delivery_mode": mode,
                    "attempt_no": attempt_no,
                    "external_reference": next_external_reference,
                }
            ),
        ),
    )
    return updated

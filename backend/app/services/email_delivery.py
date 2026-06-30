from __future__ import annotations

import smtplib
import uuid
from email.message import EmailMessage
from typing import Any

from psycopg.types.json import Jsonb

from app.core.config import settings
from app.domain.statuses import DistributionStatus, MeetingStatus
from app.schemas import EmailRecipient


def delivery_mode() -> str:
    if settings.email_delivery_mode == "smtp":
        return "smtp"
    return "dev_log"


def _provider_message_id(distribution_id: str, recipient_email: str) -> str:
    return f"{delivery_mode()}:{distribution_id}:{recipient_email}:{uuid.uuid4().hex[:8]}"


def _send_one(
    distribution_id: str,
    subject: str,
    body: str,
    recipient: EmailRecipient,
) -> str:
    mode = delivery_mode()
    if mode == "dev_log":
        return _provider_message_id(distribution_id, recipient.email)

    if not settings.email_smtp_host:
        raise RuntimeError("SMTP host is not configured")

    message = EmailMessage()
    message["From"] = settings.email_from_address
    message["To"] = recipient.email
    message["Subject"] = subject
    message.set_content(body)

    with smtplib.SMTP(settings.email_smtp_host, settings.email_smtp_port, timeout=15) as smtp:
        if settings.email_smtp_use_tls:
            smtp.starttls()
        if settings.email_smtp_username:
            smtp.login(settings.email_smtp_username, settings.email_smtp_password)
        smtp.send_message(message)
    return _provider_message_id(distribution_id, recipient.email)


def _schedule_retry_sql(attempt_no: int) -> str:
    if attempt_no >= settings.email_retry_max_attempts:
        return "NULL"
    return f"now() + interval '{max(settings.email_retry_delay_seconds, 1)} seconds'"


def deliver_distribution(cursor: Any, distribution: dict) -> dict:
    recipients = [
        EmailRecipient.model_validate(recipient)
        for recipient in (distribution["recipients"] or [])
    ]
    attempt_no = int(distribution.get("attempt_count") or 0) + 1
    distribution_id = distribution["distribution_id"]
    meeting_id = distribution["meeting_id"]

    cursor.execute(
        """
        UPDATE email_distributions
        SET status = %s,
            delivery_mode = %s,
            attempt_count = %s,
            last_error = NULL
        WHERE distribution_id = %s
        """,
        (
            DistributionStatus.SENDING.value,
            delivery_mode(),
            attempt_no,
            distribution_id,
        ),
    )

    sent_count = 0
    errors: list[str] = []
    for recipient in recipients:
        error_message: str | None = None
        provider_message_id: str | None = None
        status = DistributionStatus.SENT.value
        try:
            provider_message_id = _send_one(
                distribution_id,
                distribution["subject"],
                distribution["body"],
                recipient,
            )
            sent_count += 1
        except Exception as exc:  # noqa: BLE001 - provider failures must be logged, not raised.
            status = DistributionStatus.FAILED.value
            error_message = str(exc)
            errors.append(f"{recipient.email}: {error_message}")

        cursor.execute(
            """
            INSERT INTO email_delivery_attempts
                (
                    attempt_id,
                    distribution_id,
                    recipient_email,
                    recipient_name,
                    status,
                    attempt_no,
                    provider_message_id,
                    error_message
                )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                f"EDA-{uuid.uuid4().hex[:12]}",
                distribution_id,
                recipient.email,
                recipient.name,
                status,
                attempt_no,
                provider_message_id,
                error_message,
            ),
        )

    if sent_count == len(recipients):
        final_status = DistributionStatus.SENT.value
        meeting_status = MeetingStatus.DISTRIBUTED.value
        next_retry_sql = "NULL"
        sent_at_sql = "now()"
        last_error = None
    elif sent_count > 0:
        final_status = DistributionStatus.PARTIAL_FAILED.value
        meeting_status = MeetingStatus.DISTRIBUTION_FAILED.value
        next_retry_sql = _schedule_retry_sql(attempt_no)
        sent_at_sql = "NULL"
        last_error = "; ".join(errors)
    elif attempt_no < settings.email_retry_max_attempts:
        final_status = DistributionStatus.RETRY_WAIT.value
        meeting_status = MeetingStatus.DISTRIBUTION_FAILED.value
        next_retry_sql = _schedule_retry_sql(attempt_no)
        sent_at_sql = "NULL"
        last_error = "; ".join(errors) or "No recipients were delivered"
    else:
        final_status = DistributionStatus.FAILED.value
        meeting_status = MeetingStatus.DISTRIBUTION_FAILED.value
        next_retry_sql = "NULL"
        sent_at_sql = "NULL"
        last_error = "; ".join(errors) or "No recipients were delivered"

    cursor.execute(
        f"""
        UPDATE email_distributions
        SET status = %s,
            last_error = %s,
            next_retry_at = {next_retry_sql},
            sent_at = {sent_at_sql}
        WHERE distribution_id = %s
        RETURNING distribution_id,
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
        """,
        (final_status, last_error, distribution_id),
    )
    updated = cursor.fetchone()

    cursor.execute(
        """
        UPDATE meetings
        SET status = %s
        WHERE meeting_id = %s
        """,
        (meeting_status, meeting_id),
    )
    cursor.execute(
        """
        INSERT INTO audit_logs
            (actor_user_id, action_type, target_table, target_id, after_value)
        VALUES (%s, 'email_delivery_attempt', 'email_distributions', %s, %s)
        """,
        (
            distribution.get("requested_by") or "system",
            distribution_id,
            Jsonb(
                {
                    "status": final_status,
                    "delivery_mode": delivery_mode(),
                    "attempt_no": attempt_no,
                    "recipient_count": len(recipients),
                    "sent_count": sent_count,
                    "last_error": last_error,
                }
            ),
        ),
    )
    return updated

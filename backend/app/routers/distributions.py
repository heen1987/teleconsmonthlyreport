import uuid

from fastapi import APIRouter, Depends, HTTPException
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus, DistributionStatus, MeetingStatus, MinutesStatus
from app.schemas import (
    EmailDeliveryAttemptOut,
    EmailDistributionOut,
    EmailDistributionPreviewOut,
    EmailDistributionRequest,
    EmailRecipient,
    EmailRetryDueRequest,
    MeetingAnalysisResult,
    MeetingOut,
)
from app.services.auth_tokens import require_active_user
from app.services.email_delivery import deliver_distribution, delivery_mode

router = APIRouter(prefix="/meetings", tags=["distributions"])
ops_router = APIRouter(prefix="/distributions", tags=["distributions"])


def _load_approved_context(cursor, meeting_id: str) -> tuple[dict, dict, MeetingAnalysisResult]:
    cursor.execute(
        """
        SELECT meeting_id, project_id, title, created_by, status, audio_path, transcript
        FROM meetings
        WHERE meeting_id = %s
        """,
        (meeting_id,),
    )
    meeting = cursor.fetchone()
    if meeting is None:
        raise HTTPException(status_code=404, detail="Meeting not found")
    if meeting["status"] != MeetingStatus.APPROVED.value:
        raise HTTPException(status_code=409, detail="Approved meeting is required before distribution")

    cursor.execute(
        """
        SELECT analysis_id, meeting_id, status, model_name, summary, result_json
        FROM meeting_analyses
        WHERE meeting_id = %s
          AND status = %s
        ORDER BY approved_at DESC NULLS LAST, created_at DESC
        LIMIT 1
        """,
        (meeting_id, MinutesStatus.APPROVED.value),
    )
    analysis = cursor.fetchone()
    if analysis is None:
        raise HTTPException(status_code=409, detail="Approved meeting analysis is required before distribution")

    result = MeetingAnalysisResult.model_validate(analysis["result_json"])
    return meeting, analysis, result


def _default_recipients(cursor, project_id: str) -> list[EmailRecipient]:
    cursor.execute(
        """
        SELECT u.email, u.name, pm.project_role
        FROM project_members pm
        JOIN users u ON u.user_id = pm.user_id
        WHERE pm.project_id = %s
          AND u.status = %s
          AND u.email IS NOT NULL
          AND btrim(u.email) <> ''
        ORDER BY
            CASE pm.project_role
                WHEN 'pm' THEN 1
                WHEN 'pl' THEN 2
                ELSE 3
            END,
            u.name ASC
        """,
        (project_id, AccountStatus.ACTIVE.value),
    )
    return [
        EmailRecipient(email=row["email"], name=row["name"], role=row["project_role"])
        for row in cursor.fetchall()
    ]


def _normalize_recipients(recipients: list[EmailRecipient]) -> list[EmailRecipient]:
    normalized: list[EmailRecipient] = []
    seen: set[str] = set()
    for recipient in recipients:
        email = recipient.email.strip()
        if not email:
            continue
        key = email.lower()
        if key in seen:
            continue
        seen.add(key)
        normalized.append(
            EmailRecipient(
                email=email,
                name=recipient.name.strip() if recipient.name else None,
                role=recipient.role.strip() if recipient.role else None,
            )
        )
    return normalized


def _format_preview_body(meeting: dict, result: MeetingAnalysisResult) -> str:
    lines = [
        "안녕하세요.",
        "",
        f"'{meeting['title']}' 회의록이 승인되어 공유드립니다.",
        "",
        "[요약]",
        result.summary,
    ]
    if result.decisions:
        lines.extend(["", "[주요 결정]"])
        lines.extend(f"- {item.content}" for item in result.decisions)
    if result.action_items:
        lines.extend(["", "[Action Items]"])
        for item in result.action_items:
            due = f" / {item.due_date}" if item.due_date else ""
            assignee = item.assignee or "담당자 미정"
            lines.append(f"- {item.title} ({assignee}{due})")
    if result.risks:
        lines.extend(["", "[Risks]"])
        lines.extend(f"- {item.title} ({item.level})" for item in result.risks)
    if result.required_resources:
        lines.extend(["", "[Required Resources]"])
        for item in result.required_resources:
            quantity = f" x {item.quantity:g}" if item.quantity is not None else ""
            lines.append(f"- {item.name} ({item.resource_type}{quantity})")
    lines.extend(["", "AI-PMS"])
    return "\n".join(lines)


def _build_preview(cursor, meeting_id: str) -> EmailDistributionPreviewOut:
    meeting, analysis, result = _load_approved_context(cursor, meeting_id)
    recipients = _default_recipients(cursor, meeting["project_id"])
    return EmailDistributionPreviewOut(
        meeting=MeetingOut.model_validate(meeting),
        analysis_id=analysis["analysis_id"],
        subject=f"[AI-PMS] {meeting['title']} 회의록",
        body=_format_preview_body(meeting, result),
        recipients=recipients,
        can_distribute=True,
        delivery_mode=delivery_mode(),
    )


def _delivery_attempts(cursor, distribution_id: str) -> list[EmailDeliveryAttemptOut]:
    cursor.execute(
        """
        SELECT attempt_id,
            recipient_email,
            recipient_name,
            status,
            attempt_no,
            provider_message_id,
            error_message,
            attempted_at
        FROM email_delivery_attempts
        WHERE distribution_id = %s
        ORDER BY attempted_at ASC, attempt_id ASC
        """,
        (distribution_id,),
    )
    return [EmailDeliveryAttemptOut.model_validate(row) for row in cursor.fetchall()]


def _distribution_from_row(cursor, row: dict) -> EmailDistributionOut:
    payload = dict(row)
    payload["recipients"] = row["recipients"] or []
    payload["attempts"] = _delivery_attempts(cursor, row["distribution_id"])
    return EmailDistributionOut.model_validate(payload)


def _select_distribution(cursor, distribution_id: str) -> dict | None:
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
        WHERE distribution_id = %s
        """,
        (distribution_id,),
    )
    return cursor.fetchone()


@router.get("/{meeting_id}/distribution-preview", response_model=EmailDistributionPreviewOut)
def get_distribution_preview(
    meeting_id: str,
    current_user: dict = Depends(require_active_user),
):
    _ = current_user
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            return _build_preview(cursor, meeting_id)


@router.post("/{meeting_id}/distribute", response_model=EmailDistributionOut)
def distribute_meeting(
    meeting_id: str,
    payload: EmailDistributionRequest,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            preview = _build_preview(cursor, meeting_id)
            recipients = _normalize_recipients(preview.recipients)
            if not recipients:
                raise HTTPException(status_code=422, detail="At least one project member recipient is required")

            cursor.execute(
                """
                SELECT distribution_id
                FROM email_distributions
                WHERE analysis_id = %s
                  AND status IN ('queued', 'sending', 'sent', 'partial_failed', 'failed', 'retry_wait')
                LIMIT 1
                """,
                (preview.analysis_id,),
            )
            existing = cursor.fetchone()
            if existing is not None:
                raise HTTPException(status_code=409, detail="Meeting analysis is already distributed")

            subject = (payload.subject or preview.subject).strip()
            body = (payload.body or preview.body).strip()
            if not subject or not body:
                raise HTTPException(status_code=422, detail="Subject and body are required")

            distribution_id = f"DST-{uuid.uuid4().hex[:12]}"
            recipients_payload = [recipient.model_dump() for recipient in recipients]
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
                        sent_at
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 0, NULL)
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
                (
                    distribution_id,
                    meeting_id,
                    preview.analysis_id,
                    subject,
                    body,
                    Jsonb(recipients_payload),
                    DistributionStatus.QUEUED.value,
                    delivery_mode(),
                    current_user["user_id"],
                ),
            )
            distribution = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'distribute_meeting_minutes', 'email_distributions', %s, %s)
                """,
                (
                    current_user["user_id"],
                    distribution_id,
                    Jsonb(
                        {
                            "meeting_id": meeting_id,
                            "analysis_id": preview.analysis_id,
                            "status": DistributionStatus.QUEUED.value,
                            "delivery_mode": delivery_mode(),
                            "recipient_policy": "project_members_auto",
                            "recipient_count": len(recipients),
                        }
                    ),
                ),
            )
            delivered = deliver_distribution(cursor, distribution)
            return _distribution_from_row(cursor, delivered)


@router.get("/{meeting_id}/distributions", response_model=list[EmailDistributionOut])
def list_meeting_distributions(
    meeting_id: str,
    current_user: dict = Depends(require_active_user),
):
    _ = current_user
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT meeting_id FROM meetings WHERE meeting_id = %s", (meeting_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="Meeting not found")

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
                WHERE meeting_id = %s
                ORDER BY created_at DESC
                """,
                (meeting_id,),
            )
            return [_distribution_from_row(cursor, row) for row in cursor.fetchall()]


@router.post("/{meeting_id}/distributions/{distribution_id}/retry", response_model=EmailDistributionOut)
def retry_meeting_distribution(
    meeting_id: str,
    distribution_id: str,
    current_user: dict = Depends(require_active_user),
):
    _ = current_user
    retryable_statuses = {
        DistributionStatus.FAILED.value,
        DistributionStatus.PARTIAL_FAILED.value,
        DistributionStatus.RETRY_WAIT.value,
    }
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            distribution = _select_distribution(cursor, distribution_id)
            if distribution is None or distribution["meeting_id"] != meeting_id:
                raise HTTPException(status_code=404, detail="Distribution not found")
            if distribution["status"] not in retryable_statuses:
                raise HTTPException(status_code=409, detail="Distribution is not retryable")
            delivered = deliver_distribution(cursor, distribution)
            return _distribution_from_row(cursor, delivered)


@ops_router.post("/retry-due", response_model=list[EmailDistributionOut])
def retry_due_distributions(
    payload: EmailRetryDueRequest,
    current_user: dict = Depends(require_active_user),
):
    _ = current_user
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
                (payload.limit,),
            )
            due_rows = cursor.fetchall()
            delivered_rows = [deliver_distribution(cursor, row) for row in due_rows]
            return [_distribution_from_row(cursor, row) for row in delivered_rows]

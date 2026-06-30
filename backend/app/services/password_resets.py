from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from app.domain.statuses import AccountStatus
from app.services.passwords import hash_password


def _hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _expire_due_tokens(cursor: Any) -> None:
    cursor.execute(
        """
        UPDATE password_reset_tokens
        SET status = 'expired'
        WHERE status = 'pending'
          AND expires_at <= now()
        """
    )


def issue_password_reset_token(
    cursor: Any,
    *,
    employee_no: str,
    email: str,
    ttl_seconds: int,
) -> tuple[dict | None, str | None, datetime | None]:
    _expire_due_tokens(cursor)
    cursor.execute(
        """
        SELECT user_id, employee_no, name, email, role, status
        FROM users
        WHERE employee_no = %s
          AND lower(coalesce(email, '')) = lower(%s)
        """,
        (employee_no, email),
    )
    user = cursor.fetchone()
    if user is None:
        return None, None, None
    if user["status"] in {AccountStatus.LOCKED.value, AccountStatus.DISABLED.value}:
        return user, None, None

    cursor.execute(
        """
        UPDATE password_reset_tokens
        SET status = 'expired'
        WHERE user_id = %s
          AND status = 'pending'
        """,
        (user["user_id"],),
    )
    token = f"aipms_reset_{secrets.token_urlsafe(32)}"
    expires_at = datetime.now(UTC) + timedelta(seconds=ttl_seconds)
    cursor.execute(
        """
        INSERT INTO password_reset_tokens
            (reset_token_id, user_id, token_hash, requested_email, expires_at)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            f"PRT-{uuid.uuid4().hex[:12]}",
            user["user_id"],
            _hash_reset_token(token),
            email,
            expires_at,
        ),
    )
    return user, token, expires_at


def verify_password_reset_token(cursor: Any, token: str) -> dict | None:
    _expire_due_tokens(cursor)
    cursor.execute(
        """
        SELECT
            prt.reset_token_id,
            prt.expires_at,
            u.user_id,
            u.employee_no,
            u.name,
            u.email,
            u.role,
            u.status
        FROM password_reset_tokens prt
        JOIN users u ON u.user_id = prt.user_id
        WHERE prt.token_hash = %s
          AND prt.status = 'pending'
          AND prt.used_at IS NULL
          AND prt.expires_at > now()
        """,
        (_hash_reset_token(token),),
    )
    row = cursor.fetchone()
    if row is None:
        return None
    cursor.execute(
        """
        UPDATE password_reset_tokens
        SET last_verified_at = now()
        WHERE reset_token_id = %s
        """,
        (row["reset_token_id"],),
    )
    return row


def confirm_password_reset(
    cursor: Any,
    *,
    token: str,
    new_password: str,
) -> tuple[dict | None, int]:
    row = verify_password_reset_token(cursor, token)
    if row is None:
        return None, 0
    if row["status"] in {AccountStatus.LOCKED.value, AccountStatus.DISABLED.value}:
        return row, 0

    cursor.execute(
        """
        UPDATE users
        SET password_hash = %s, status = %s, updated_at = now()
        WHERE user_id = %s
        RETURNING user_id, employee_no, name, email, role, status
        """,
        (hash_password(new_password), AccountStatus.ACTIVE.value, row["user_id"]),
    )
    user = cursor.fetchone()
    cursor.execute(
        """
        UPDATE access_tokens
        SET revoked_at = now()
        WHERE user_id = %s
          AND revoked_at IS NULL
        """,
        (row["user_id"],),
    )
    revoked_tokens = cursor.rowcount
    cursor.execute(
        """
        UPDATE password_reset_tokens
        SET status = 'used', used_at = now()
        WHERE reset_token_id = %s
        """,
        (row["reset_token_id"],),
    )
    cursor.execute(
        """
        UPDATE password_reset_tokens
        SET status = 'expired'
        WHERE user_id = %s
          AND status = 'pending'
        """,
        (row["user_id"],),
    )
    return user, revoked_tokens

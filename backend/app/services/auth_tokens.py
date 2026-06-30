from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import Depends, Header, HTTPException
from psycopg.rows import dict_row

from app.core.config import settings
from app.db.session import get_connection
from app.domain.statuses import AccountStatus


def _hash_access_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_access_token(cursor: Any, user_id: str) -> tuple[str, datetime]:
    token = f"aipms_{secrets.token_urlsafe(32)}"
    expires_at = datetime.now(UTC) + timedelta(seconds=settings.access_token_ttl_seconds)
    cursor.execute(
        """
        INSERT INTO access_tokens (token_id, user_id, token_hash, expires_at)
        VALUES (%s, %s, %s, %s)
        """,
        (
            f"AT-{uuid.uuid4().hex[:12]}",
            user_id,
            _hash_access_token(token),
            expires_at,
        ),
    )
    return token, expires_at


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid bearer token")
    return token


def require_current_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> dict:
    token = _bearer_token(authorization)
    token_hash = _hash_access_token(token)
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT u.user_id, u.employee_no, u.name, u.email, u.role, u.status
                FROM access_tokens at
                JOIN users u ON u.user_id = at.user_id
                WHERE at.token_hash = %s
                  AND at.revoked_at IS NULL
                  AND at.expires_at > now()
                """,
                (token_hash,),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=401, detail="Invalid or expired bearer token")
            if row["status"] in {AccountStatus.LOCKED.value, AccountStatus.DISABLED.value}:
                raise HTTPException(status_code=403, detail="Access denied")
            cursor.execute(
                """
                UPDATE access_tokens
                SET last_used_at = now()
                WHERE token_hash = %s
                """,
                (token_hash,),
            )
    return row


def require_active_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> dict:
    row = require_current_user(authorization)
    if row["status"] == AccountStatus.PASSWORD_CHANGE_REQUIRED.value:
        raise HTTPException(status_code=403, detail="Password change required")
    return row


def require_admin_user(current_user: dict = Depends(require_active_user)) -> dict:
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return current_user


def revoke_current_token(authorization: str | None) -> None:
    token = _bearer_token(authorization)
    token_hash = _hash_access_token(token)
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE access_tokens
                SET revoked_at = now()
                WHERE token_hash = %s
                  AND revoked_at IS NULL
                """,
                (token_hash,),
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=401, detail="Invalid or expired bearer token")

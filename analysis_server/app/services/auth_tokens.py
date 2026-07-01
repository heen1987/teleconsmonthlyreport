from __future__ import annotations

import hashlib
import secrets

from fastapi import Header, HTTPException
from psycopg.rows import dict_row

from app.core.config import settings
from app.db.session import get_connection


DENIED_ACCOUNT_STATUSES = {"locked", "disabled"}


def _hash_access_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid bearer token")
    return token


def _configured_internal_secret() -> str:
    """내부 클라이언트 인증 시크릿 — platform_callback_secret 을 공유 사용한다."""
    return settings.platform_callback_secret


def require_internal_client(
    x_internal_secret: str | None = Header(default=None, alias="X-Internal-Secret"),
) -> dict:
    expected = _configured_internal_secret()
    if not expected or not x_internal_secret:
        raise HTTPException(status_code=401, detail="Missing internal client secret")
    if not secrets.compare_digest(x_internal_secret, expected):
        raise HTTPException(status_code=403, detail="Invalid internal client secret")
    return {"auth_type": "internal"}


def require_active_user(
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
            if row["status"] in DENIED_ACCOUNT_STATUSES:
                raise HTTPException(status_code=403, detail="Access denied")
            if row["status"] == "password_change_required":
                raise HTTPException(status_code=403, detail="Password change required")
            cursor.execute(
                """
                UPDATE access_tokens
                SET last_used_at = now()
                WHERE token_hash = %s
                """,
                (token_hash,),
            )
    return row


def require_user_or_internal_client(
    authorization: str | None = Header(default=None, alias="Authorization"),
    x_internal_secret: str | None = Header(default=None, alias="X-Internal-Secret"),
) -> dict:
    expected = _configured_internal_secret()
    if expected and x_internal_secret:
        if secrets.compare_digest(x_internal_secret, expected):
            return {"auth_type": "internal"}
        raise HTTPException(status_code=403, detail="Invalid internal client secret")
    return require_active_user(authorization)

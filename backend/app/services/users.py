from __future__ import annotations

import uuid
from typing import Any

from app.domain.statuses import AccountStatus
from app.schemas import UserCreate, UserUpdate
from app.services.passwords import hash_password


def create_user_record(
    cursor: Any,
    payload: UserCreate,
    *,
    status: str = AccountStatus.PASSWORD_CHANGE_REQUIRED.value,
) -> dict:
    user_id = f"USR-{uuid.uuid4().hex[:12]}"
    cursor.execute(
        """
        INSERT INTO users
            (user_id, employee_no, name, email, role, password_hash, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING user_id, employee_no, name, email, role, status
        """,
        (
            user_id,
            payload.employee_no,
            payload.name,
            payload.email,
            payload.role,
            hash_password(payload.initial_password),
            status,
        ),
    )
    return cursor.fetchone()


def get_user_record(cursor: Any, user_id: str) -> dict | None:
    cursor.execute(
        """
        SELECT user_id, employee_no, name, email, role, status
        FROM users
        WHERE user_id = %s
        """,
        (user_id,),
    )
    return cursor.fetchone()


def update_user_record(cursor: Any, user_id: str, payload: UserUpdate) -> dict | None:
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        return get_user_record(cursor, user_id)

    set_clauses: list[str] = []
    values: list[Any] = []
    for column in ("name", "email", "role", "status"):
        if column in fields:
            if fields[column] is None and column != "email":
                continue
            set_clauses.append(f"{column} = %s")
            values.append(fields[column])

    if not set_clauses:
        return get_user_record(cursor, user_id)

    values.append(user_id)
    cursor.execute(
        f"""
        UPDATE users
        SET {", ".join(set_clauses)}, updated_at = now()
        WHERE user_id = %s
        RETURNING user_id, employee_no, name, email, role, status
        """,
        values,
    )
    return cursor.fetchone()


def reset_user_password(
    cursor: Any,
    user_id: str,
    new_password: str,
    *,
    force_password_change: bool = True,
) -> tuple[dict | None, int]:
    next_status = (
        AccountStatus.PASSWORD_CHANGE_REQUIRED.value
        if force_password_change
        else AccountStatus.ACTIVE.value
    )
    cursor.execute(
        """
        UPDATE users
        SET password_hash = %s, status = %s, updated_at = now()
        WHERE user_id = %s
        RETURNING user_id, employee_no, name, email, role, status
        """,
        (hash_password(new_password), next_status, user_id),
    )
    user = cursor.fetchone()
    if user is None:
        return None, 0

    cursor.execute(
        """
        UPDATE access_tokens
        SET revoked_at = now()
        WHERE user_id = %s
          AND revoked_at IS NULL
        """,
        (user_id,),
    )
    return user, cursor.rowcount

from fastapi import APIRouter, Depends, HTTPException
from psycopg.errors import UniqueViolation
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.schemas import AdminPasswordResetOut, AdminPasswordResetRequest, UserCreate, UserOut, UserUpdate
from app.services.auth_tokens import require_admin_user
from app.services.users import create_user_record, get_user_record, reset_user_password, update_user_record

router = APIRouter(prefix="/admin/users", tags=["admin-users"])


@router.post("", response_model=UserOut)
def create_user(payload: UserCreate, current_user: dict = Depends(require_admin_user)):
    try:
        with get_connection() as connection:
            with connection.cursor(row_factory=dict_row) as cursor:
                created = create_user_record(cursor, payload)
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'admin_user_create', 'users', %s, %s)
                    """,
                    (current_user["user_id"], created["user_id"], Jsonb(dict(created))),
                )
                return created
    except UniqueViolation as exc:
        raise HTTPException(status_code=409, detail="Employee number already exists") from exc


@router.get("", response_model=list[UserOut])
def list_users(_current_user: dict = Depends(require_admin_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT user_id, employee_no, name, email, role, status
                FROM users
                ORDER BY created_at DESC
                """
            )
            rows = cursor.fetchall()
    return rows


@router.put("/{user_id}", response_model=UserOut)
def update_user(
    user_id: str,
    payload: UserUpdate,
    current_user: dict = Depends(require_admin_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            before = get_user_record(cursor, user_id)
            if before is None:
                raise HTTPException(status_code=404, detail="User not found")
            updated = update_user_record(cursor, user_id, payload)
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'admin_user_update', 'users', %s, %s, %s)
                """,
                (current_user["user_id"], user_id, Jsonb(dict(before)), Jsonb(dict(updated))),
            )
            return updated


@router.post("/{user_id}/reset-password", response_model=AdminPasswordResetOut)
def reset_password(
    user_id: str,
    payload: AdminPasswordResetRequest,
    current_user: dict = Depends(require_admin_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            before = get_user_record(cursor, user_id)
            if before is None:
                raise HTTPException(status_code=404, detail="User not found")
            user, revoked_tokens = reset_user_password(
                cursor,
                user_id,
                payload.new_password,
                force_password_change=payload.force_password_change,
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'admin_password_reset', 'users', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    user_id,
                    Jsonb(dict(before)),
                    Jsonb({"status": user["status"], "revoked_tokens": revoked_tokens}),
                ),
            )
    return AdminPasswordResetOut(
        user=user,
        password_change_required=user["status"] == "password_change_required",
        revoked_tokens=revoked_tokens,
    )

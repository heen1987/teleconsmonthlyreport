from fastapi import APIRouter, Depends, Header, HTTPException
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.core.config import settings
from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.schemas import (
    LoginOut,
    LoginRequest,
    PasswordChangeRequest,
    PasswordResetConfirmOut,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    PasswordResetRequestOut,
    PasswordResetVerifyOut,
    UserOut,
)
from app.services.auth_tokens import issue_access_token, require_active_user, require_current_user, revoke_current_token
from app.services.password_resets import confirm_password_reset, issue_password_reset_token, verify_password_reset_token
from app.services.passwords import hash_password, verify_password

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/login", response_model=LoginOut)
def login(payload: LoginRequest):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT user_id, employee_no, name, email, role, status, password_hash
                FROM users
                WHERE employee_no = %s
                """,
                (payload.employee_no,),
            )
            row = cursor.fetchone()
            if row is None or not verify_password(payload.password, row["password_hash"]):
                raise HTTPException(status_code=401, detail="Invalid employee number or password")
            if row["status"] in {AccountStatus.LOCKED.value, AccountStatus.DISABLED.value}:
                raise HTTPException(status_code=403, detail="Access denied")
            access_token, expires_at = issue_access_token(cursor, row["user_id"])

    user = UserOut.model_validate(row)
    return LoginOut(
        access_token=access_token,
        expires_at=expires_at,
        user=user,
        password_change_required=row["status"] == AccountStatus.PASSWORD_CHANGE_REQUIRED.value,
    )


@router.get("/me", response_model=UserOut)
def me(current_user: dict = Depends(require_current_user)):
    return current_user


@router.post("/logout")
def logout(authorization: str | None = Header(default=None, alias="Authorization")):
    revoke_current_token(authorization)
    return {"status": "logged_out"}


@router.post("/password/change")
def change_password(
    payload: PasswordChangeRequest,
    current_user: dict = Depends(require_current_user),
):
    # 본인 비밀번호만 변경 가능 — 타인 employee_no 요청 차단
    if current_user["employee_no"] != payload.employee_no:
        raise HTTPException(status_code=403, detail="Cannot change another user's password")
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT employee_no, password_hash
                FROM users
                WHERE employee_no = %s
                """,
                (payload.employee_no,),
            )
            row = cursor.fetchone()
            if row is None or not verify_password(payload.current_password, row["password_hash"]):
                raise HTTPException(status_code=401, detail="Invalid employee number or password")
            cursor.execute(
                """
                UPDATE users
                SET password_hash = %s, status = %s, updated_at = now()
                WHERE employee_no = %s
                """,
                (hash_password(payload.new_password), AccountStatus.ACTIVE.value, payload.employee_no),
            )
            cursor.execute(
                """
                UPDATE access_tokens
                SET revoked_at = now()
                WHERE user_id = (
                    SELECT user_id
                    FROM users
                    WHERE employee_no = %s
                )
                  AND revoked_at IS NULL
                """,
                (payload.employee_no,),
            )
    return {"employee_no": payload.employee_no, "status": AccountStatus.ACTIVE.value}


@router.post("/password-reset/request", response_model=PasswordResetRequestOut)
def request_password_reset(payload: PasswordResetRequest):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            user, token, expires_at = issue_password_reset_token(
                cursor,
                employee_no=payload.employee_no,
                email=payload.email,
                ttl_seconds=settings.password_reset_token_ttl_seconds,
            )
            if user is None:
                raise HTTPException(status_code=404, detail="Account and email do not match")
            if token is None or expires_at is None:
                raise HTTPException(status_code=403, detail="Access denied")
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (NULL, 'password_reset_requested', 'users', %s, %s)
                """,
                (
                    user["user_id"],
                    Jsonb(
                        {
                            "employee_no": user["employee_no"],
                            "email": payload.email,
                            "expires_at": expires_at.isoformat(),
                            "delivery_mode": settings.password_reset_delivery_mode,
                        }
                    ),
                ),
            )
    return PasswordResetRequestOut(
        employee_no=user["employee_no"],
        email=payload.email,
        expires_at=expires_at,
        delivery_status="dev_token_returned",
        reset_token=token,
    )


@router.get("/password-reset/verify", response_model=PasswordResetVerifyOut)
def verify_password_reset(token: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            row = verify_password_reset_token(cursor, token)
            if row is None:
                raise HTTPException(status_code=404, detail="Invalid or expired reset token")
    return PasswordResetVerifyOut(
        valid=True,
        employee_no=row["employee_no"],
        email=row["email"],
        expires_at=row["expires_at"],
    )


@router.post("/password-reset/confirm", response_model=PasswordResetConfirmOut)
def confirm_password_reset_endpoint(payload: PasswordResetConfirmRequest):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            user, revoked_tokens = confirm_password_reset(
                cursor,
                token=payload.token,
                new_password=payload.new_password,
            )
            if user is None:
                raise HTTPException(status_code=404, detail="Invalid or expired reset token")
            if user["status"] in {AccountStatus.LOCKED.value, AccountStatus.DISABLED.value}:
                raise HTTPException(status_code=403, detail="Access denied")
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (NULL, 'password_reset_confirmed', 'users', %s, %s)
                """,
                (
                    user["user_id"],
                    Jsonb({"employee_no": user["employee_no"], "status": user["status"], "revoked_tokens": revoked_tokens}),
                ),
            )
    return PasswordResetConfirmOut(
        employee_no=user["employee_no"],
        status=user["status"],
        revoked_tokens=revoked_tokens,
    )

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "backend"))

from psycopg.rows import dict_row

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.schemas import UserCreate
from app.services.passwords import hash_password
from app.services.users import create_user_record


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed a Platform API user directly into the local DB.")
    parser.add_argument("--employee-no", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--email")
    parser.add_argument("--role", default="member")
    parser.add_argument("--password", default="1234")
    parser.add_argument(
        "--status",
        choices=[status.value for status in AccountStatus],
        default=AccountStatus.PASSWORD_CHANGE_REQUIRED.value,
    )
    parser.add_argument(
        "--reset-password",
        action="store_true",
        help="Update an existing user's password/status and revoke active tokens.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    payload = UserCreate(
        employee_no=args.employee_no,
        name=args.name,
        email=args.email,
        role=args.role,
        initial_password=args.password,
    )

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT user_id, employee_no, name, email, role, status
                FROM users
                WHERE employee_no = %s
                """,
                (payload.employee_no,),
            )
            existing = cursor.fetchone()
            if existing is None:
                row = create_user_record(cursor, payload, status=args.status)
                created = True
            elif args.reset_password:
                cursor.execute(
                    """
                    UPDATE users
                    SET name = %s,
                        email = %s,
                        role = %s,
                        password_hash = %s,
                        status = %s,
                        updated_at = now()
                    WHERE employee_no = %s
                    RETURNING user_id, employee_no, name, email, role, status
                    """,
                    (
                        payload.name,
                        payload.email,
                        payload.role,
                        hash_password(payload.initial_password),
                        args.status,
                        payload.employee_no,
                    ),
                )
                row = cursor.fetchone()
                cursor.execute(
                    """
                    UPDATE access_tokens
                    SET revoked_at = now()
                    WHERE user_id = %s
                      AND revoked_at IS NULL
                    """,
                    (row["user_id"],),
                )
                created = False
            else:
                row = existing
                created = False

    print(json.dumps({"created": created, "user": row}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()

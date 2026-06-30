#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import psycopg
from psycopg.rows import dict_row


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply SQL migrations once per service.")
    parser.add_argument("--database-url", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--migrations-dir", required=True)
    return parser.parse_args()


def migration_files(migrations_dir: Path) -> list[Path]:
    files = sorted(path for path in migrations_dir.glob("*.sql") if path.is_file())
    if not files:
        raise SystemExit(f"No migration files found in {migrations_dir}")
    return files


def checksum(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def main() -> None:
    args = parse_args()
    service = args.service
    files = migration_files(Path(args.migrations_dir))

    with psycopg.connect(args.database_url) as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", ("ai_pms_migrations",))
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    service TEXT NOT NULL,
                    version TEXT NOT NULL,
                    name TEXT NOT NULL,
                    checksum_sha256 TEXT NOT NULL,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                    PRIMARY KEY (service, version)
                )
                """
            )

            for path in files:
                version = path.stem
                content = path.read_text(encoding="utf-8")
                content_checksum = checksum(content)
                cursor.execute(
                    """
                    SELECT checksum_sha256
                    FROM schema_migrations
                    WHERE service = %s AND version = %s
                    """,
                    (service, version),
                )
                row = cursor.fetchone()
                if row is not None:
                    if row["checksum_sha256"] != content_checksum:
                        raise SystemExit(
                            f"Migration checksum mismatch: service={service} version={version}"
                        )
                    print(f"skip {service} {version}")
                    continue

                print(f"apply {service} {version}")
                cursor.execute(content)
                cursor.execute(
                    """
                    INSERT INTO schema_migrations
                        (service, version, name, checksum_sha256)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (service, version, path.name, content_checksum),
                )


if __name__ == "__main__":
    main()

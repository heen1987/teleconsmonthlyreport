# Database Migration Policy

Last updated: 2026-06-27

## Purpose

Platform API and Collection API now apply database changes through service
migrations instead of sending `schema.sql` directly to PostgreSQL.

The `schema.sql` files remain readable schema snapshots. The authoritative
runtime path is the migration directory for each service.

## Migration Layout

```text
backend/migrations/
  0001_platform_initial.sql
  0002_password_reset_tokens.sql
  0003_email_distributions.sql
  0004_email_delivery_retry.sql
  0005_resource_allocation.sql
  0006_resource_profiles.sql

collection_api/migrations/
  0001_collection_initial.sql

scripts/run_migrations.py
```

`scripts/run_migrations.py` creates and uses a shared `schema_migrations` table:

- `service`
- `version`
- `name`
- `checksum_sha256`
- `applied_at`

Each migration is applied once per service. If an already-applied migration file
changes, the runner stops with a checksum mismatch instead of silently accepting
drift.

The runner also takes a PostgreSQL transaction-level advisory lock before
creating or reading `schema_migrations`, so Platform and Collection startup can
race safely.

## Commands

Platform:

```bash
bash scripts/apply_platform_schema.sh
```

Collection:

```bash
bash scripts/apply_collection_schema.sh
```

The service run scripts call these automatically before starting the API:

```bash
bash scripts/run_platform_backend.sh
bash scripts/run_collection_api.sh
```

## Development Rule

For future database changes:

1. Add a new numbered SQL file under the service migration directory.
2. Keep the SQL idempotent when practical by using `IF NOT EXISTS`.
3. Do not edit a migration after it has been applied to a shared or production
   database.
4. Update `schema.sql` as a human-readable snapshot if the structure changes.
5. Run the corresponding `apply_*_schema.sh` script twice to verify apply then
   skip behavior.

## Verification

```bash
bash scripts/apply_platform_schema.sh
bash scripts/apply_platform_schema.sh
bash scripts/apply_collection_schema.sh
bash scripts/apply_collection_schema.sh
bash scripts/verify_mvp_static.sh
```

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash scripts/apply_platform_schema.sh >/dev/null

backend/.venv/bin/python scripts/seed_platform_user.py \
  --employee-no admin \
  --name Admin \
  --role admin \
  --password 1234 \
  --status active \
  --reset-password

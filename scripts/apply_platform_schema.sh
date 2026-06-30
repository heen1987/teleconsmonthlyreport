#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/backend"

cd "$APP_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

DATABASE_URL="${DATABASE_URL:-$(grep '^DATABASE_URL=' .env | tail -n 1 | cut -d= -f2-)}"

if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL is not set." >&2
  exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  if [ -x /opt/homebrew/bin/python3.12 ]; then
    PYTHON_BIN="/opt/homebrew/bin/python3.12"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  else
    echo "python3 not found. Install Python 3.12 or set PYTHON_BIN." >&2
    exit 1
  fi
fi

if [ ! -x .venv/bin/python ]; then
  "$PYTHON_BIN" -m venv .venv
fi

if ! .venv/bin/python - <<'PY' >/dev/null 2>&1
import psycopg
PY
then
  .venv/bin/python -m pip install -r requirements.txt >/dev/null
fi

"$APP_DIR/.venv/bin/python" "$ROOT_DIR/scripts/run_migrations.py" \
  --database-url "$DATABASE_URL" \
  --service platform \
  --migrations-dir "$APP_DIR/migrations"

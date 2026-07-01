#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/backend"

cd "$APP_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/bin/python3.12}"

env_file_value() {
  local key="$1"
  if [ -f .env ]; then
    awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2) }' .env | tail -1
  fi
}

PLATFORM_BIND_HOST="${AIPMS_PLATFORM_BIND_HOST:-$(env_file_value AIPMS_PLATFORM_BIND_HOST)}"
PLATFORM_BIND_HOST="${PLATFORM_BIND_HOST:-127.0.0.1}"
PLATFORM_PORT="${AIPMS_PLATFORM_PORT:-$(env_file_value AIPMS_PLATFORM_PORT)}"
PLATFORM_PORT="${PLATFORM_PORT:-8000}"
PLATFORM_ALLOW_PUBLIC_BIND="${AIPMS_PLATFORM_ALLOW_PUBLIC_BIND:-$(env_file_value AIPMS_PLATFORM_ALLOW_PUBLIC_BIND)}"
PLATFORM_ALLOW_PUBLIC_BIND="${PLATFORM_ALLOW_PUBLIC_BIND:-0}"

case "$PLATFORM_BIND_HOST" in
  "0.0.0.0"|"::")
    if [ "$PLATFORM_ALLOW_PUBLIC_BIND" != "1" ]; then
      cat >&2 <<'EOF'
Refusing to bind Platform API to a public interface.

Default external-network policy:
  - keep Platform API on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  AIPMS_PLATFORM_BIND_HOST=0.0.0.0 AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1 bash scripts/run_platform_backend.sh
EOF
      exit 1
    fi
    ;;
esac

if [ ! -d .venv ]; then
  "$PYTHON_BIN" -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt

bash "$ROOT_DIR/scripts/apply_platform_schema.sh"

echo "Platform API bind: ${PLATFORM_BIND_HOST}:${PLATFORM_PORT}"
export PLATFORM_BIND_HOST PLATFORM_PORT
python - <<'PY'
import os

import uvicorn
from app.main import app

uvicorn.run(
    app,
    host=os.environ["PLATFORM_BIND_HOST"],
    port=int(os.environ["PLATFORM_PORT"]),
)
PY

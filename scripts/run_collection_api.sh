#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/collection_api"

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

COLLECTION_BIND_HOST="${AIPMS_COLLECTION_BIND_HOST:-$(env_file_value AIPMS_COLLECTION_BIND_HOST)}"
COLLECTION_BIND_HOST="${COLLECTION_BIND_HOST:-127.0.0.1}"
COLLECTION_PORT="${AIPMS_COLLECTION_PORT:-$(env_file_value AIPMS_COLLECTION_PORT)}"
COLLECTION_PORT="${COLLECTION_PORT:-8200}"
COLLECTION_ALLOW_PUBLIC_BIND="${AIPMS_COLLECTION_ALLOW_PUBLIC_BIND:-$(env_file_value AIPMS_COLLECTION_ALLOW_PUBLIC_BIND)}"
COLLECTION_ALLOW_PUBLIC_BIND="${COLLECTION_ALLOW_PUBLIC_BIND:-0}"

case "$COLLECTION_BIND_HOST" in
  "0.0.0.0"|"::")
    if [ "$COLLECTION_ALLOW_PUBLIC_BIND" != "1" ]; then
      cat >&2 <<'EOF'
Refusing to bind Collection API to a public interface.

Default external-network policy:
  - keep Collection API on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  AIPMS_COLLECTION_BIND_HOST=0.0.0.0 AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1 bash scripts/run_collection_api.sh
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

bash "$ROOT_DIR/scripts/apply_collection_schema.sh"

echo "Collection API bind: ${COLLECTION_BIND_HOST}:${COLLECTION_PORT}"
uvicorn app.main:app --host "$COLLECTION_BIND_HOST" --port "$COLLECTION_PORT"

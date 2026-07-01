#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/analysis_server"

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

ANALYSIS_BIND_HOST="${AIPMS_ANALYSIS_BIND_HOST:-$(env_file_value AIPMS_ANALYSIS_BIND_HOST)}"
ANALYSIS_BIND_HOST="${ANALYSIS_BIND_HOST:-127.0.0.1}"
ANALYSIS_PORT="${AIPMS_ANALYSIS_PORT:-$(env_file_value AIPMS_ANALYSIS_PORT)}"
ANALYSIS_PORT="${ANALYSIS_PORT:-8100}"
ANALYSIS_ALLOW_PUBLIC_BIND="${AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND:-$(env_file_value AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND)}"
ANALYSIS_ALLOW_PUBLIC_BIND="${ANALYSIS_ALLOW_PUBLIC_BIND:-0}"

case "$ANALYSIS_BIND_HOST" in
  "0.0.0.0"|"::")
    if [ "$ANALYSIS_ALLOW_PUBLIC_BIND" != "1" ]; then
      cat >&2 <<'EOF'
Refusing to bind Analysis server to a public interface.

Default external-network policy:
  - keep Analysis server on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  AIPMS_ANALYSIS_BIND_HOST=0.0.0.0 AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND=1 bash scripts/run_analysis_server.sh
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
echo "Analysis server bind: ${ANALYSIS_BIND_HOST}:${ANALYSIS_PORT}"
export ANALYSIS_BIND_HOST ANALYSIS_PORT
python - <<'PY'
import os

import uvicorn
from app.main import app

uvicorn.run(
    app,
    host=os.environ["ANALYSIS_BIND_HOST"],
    port=int(os.environ["ANALYSIS_PORT"]),
)
PY

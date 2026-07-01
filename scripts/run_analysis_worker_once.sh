#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/analysis_server"

cd "$APP_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

if [ -n "${PYTHON_BIN:-}" ]; then
  :
elif [ -x ".venv/bin/python" ]; then
  PYTHON_BIN=".venv/bin/python"
elif [ -x ".venv-win/Scripts/python.exe" ]; then
  PYTHON_BIN=".venv-win/Scripts/python.exe"
elif command -v python3 >/dev/null 2>&1; then
  python3 -m venv .venv
  PYTHON_BIN=".venv/bin/python"
  "$PYTHON_BIN" -m pip install -r requirements.txt
elif command -v py >/dev/null 2>&1; then
  py -3.12 -m venv .venv-win
  PYTHON_BIN=".venv-win/Scripts/python.exe"
  "$PYTHON_BIN" -m pip install -r requirements.txt
else
  echo "Python 3.12 runtime not found" >&2
  exit 1
fi

"$PYTHON_BIN" -m app.worker

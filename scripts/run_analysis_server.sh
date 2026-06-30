#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/analysis_server"

cd "$APP_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/bin/python3.12}"

if [ ! -d .venv ]; then
  "$PYTHON_BIN" -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8100

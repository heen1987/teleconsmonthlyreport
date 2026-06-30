#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/analysis_server"

cd "$APP_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

source .venv/bin/activate
python -m app.worker

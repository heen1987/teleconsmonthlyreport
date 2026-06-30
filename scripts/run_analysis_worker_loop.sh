#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"

while true; do
  bash "$ROOT_DIR/scripts/run_analysis_worker_once.sh" || true
  sleep "$INTERVAL_SECONDS"
done

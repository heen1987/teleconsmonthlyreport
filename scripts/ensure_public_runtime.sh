#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${AIPMS_RUNTIME_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RUNTIME_DIR="$ROOT_DIR/runtime/always_on"
SUMMARY_JSON="$RUNTIME_DIR/latest_public_runtime.json"
LOG_DIR="$ROOT_DIR/logs"
LOCK_DIR="$RUNTIME_DIR/ensure.lock"

AIPMS_PUBLIC_RUNTIME_REFRESH_APK="${AIPMS_PUBLIC_RUNTIME_REFRESH_APK:-0}"
AIPMS_PUBLIC_RUNTIME_RUN_ACCEPTANCE="${AIPMS_PUBLIC_RUNTIME_RUN_ACCEPTANCE:-0}"
AIPMS_PUBLIC_RUNTIME_REQUIRE_EXTERNAL_FLOW="${AIPMS_PUBLIC_RUNTIME_REQUIRE_EXTERNAL_FLOW:-0}"

mkdir -p "$RUNTIME_DIR" "$LOG_DIR"

cd "$ROOT_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "AI-PMS public runtime ensure is already running: $LOCK_DIR"
  exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "[$started_at] ensuring AI-PMS local stack"
bash scripts/run_local_execution_stack.sh

echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] ensuring AI-PMS public tunnels"
bash scripts/run_public_tunnels.sh
bash scripts/print_public_urls.sh | tee "$RUNTIME_DIR/public_urls.txt"

public_smoke_status="passed"
if SMOKE_OUTPUT="$(bash scripts/smoke_public_access.sh 2>&1)"; then
  :
else
  public_smoke_status="failed"
fi
printf "%s\n" "$SMOKE_OUTPUT" | tee "$RUNTIME_DIR/latest_public_smoke.txt"
if [ "$public_smoke_status" != "passed" ]; then
  echo "Public smoke failed." >&2
  exit 1
fi

acceptance_status="skipped"
if [ "$AIPMS_PUBLIC_RUNTIME_RUN_ACCEPTANCE" = "1" ]; then
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] running continuous acceptance"
  AIPMS_CONTINUOUS_REQUIRE_EXTERNAL_FLOW="$AIPMS_PUBLIC_RUNTIME_REQUIRE_EXTERNAL_FLOW" \
    bash scripts/run_continuous_acceptance_check.sh
  acceptance_status="passed"
fi

export ROOT_DIR SUMMARY_JSON started_at acceptance_status public_smoke_status
python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
summary_path = Path(os.environ["SUMMARY_JSON"])

refresh_path = root / "runtime/public_handoff/latest_refresh.json"
continuous_path = root / "runtime/continuous_acceptance/latest_report.json"

refresh = json.loads(refresh_path.read_text(encoding="utf-8")) if refresh_path.exists() else {}
if os.environ["acceptance_status"] == "passed" and continuous_path.exists():
    continuous = json.loads(continuous_path.read_text(encoding="utf-8"))
else:
    continuous = {}

summary = {
    "kind": "ai_pms_public_runtime_ensure",
    "started_at": os.environ["started_at"],
    "finished_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "acceptance_status": os.environ["acceptance_status"],
    "public_urls": refresh.get("public_urls", {}),
    "public_smoke_status": os.environ["public_smoke_status"],
    "continuous_status": continuous.get("overall_status"),
    "required_failures": continuous.get("required_failures"),
    "warnings": continuous.get("warnings"),
}

summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, ensure_ascii=False, indent=2))
PY

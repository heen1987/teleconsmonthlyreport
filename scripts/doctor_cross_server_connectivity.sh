#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/runtime/cross_server"
JSON_OUT="$OUT_DIR/latest_report.json"
MD_OUT="$OUT_DIR/latest_report.md"
TMP_BODY="${TMPDIR:-/tmp}/aipms-cross-server-body.$$"

mkdir -p "$OUT_DIR"

cleanup() {
  rm -f "$TMP_BODY"
}
trap cleanup EXIT

runtime_url() {
  local key="$1"
  python3 - "$key" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

key = sys.argv[1]
candidates = [
    Path.home() / ".aipms/public-runtime-state/runtime/always_on/latest_public_runtime.json",
    Path("runtime/always_on/latest_public_runtime.json"),
]
for path in candidates:
    if not path.exists():
        continue
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        continue
    value = data.get("public_urls", {}).get(key, "")
    if value:
        print(value.removesuffix("/docs").rstrip("/"))
        raise SystemExit(0)
raise SystemExit(0)
PY
}

PRIMARY_PLATFORM_URL="${AIPMS_PRIMARY_PLATFORM_URL:-$(runtime_url platform_docs)}"
PRIMARY_COLLECTION_URL="${AIPMS_PRIMARY_COLLECTION_URL:-$(runtime_url collection_docs)}"
PRIMARY_WEB_URL="${AIPMS_PRIMARY_WEB_URL:-$(runtime_url web_console)}"

PRIMARY_PLATFORM_URL="${PRIMARY_PLATFORM_URL:-http://127.0.0.1:8000}"
PRIMARY_COLLECTION_URL="${PRIMARY_COLLECTION_URL:-http://127.0.0.1:8200}"
PRIMARY_WEB_URL="${PRIMARY_WEB_URL:-}"

SECONDARY_HOST="${AIPMS_SECONDARY_HOST:-}"
SECONDARY_COLLECTION_URL="${AIPMS_SECONDARY_COLLECTION_URL:-}"
SECONDARY_ANALYSIS_URL="${AIPMS_SECONDARY_ANALYSIS_URL:-}"
EXPECT_SECONDARY="${AIPMS_EXPECT_SECONDARY:-0}"

if [ -n "$SECONDARY_HOST" ]; then
  SECONDARY_COLLECTION_URL="${SECONDARY_COLLECTION_URL:-http://${SECONDARY_HOST}:8200}"
  SECONDARY_ANALYSIS_URL="${SECONDARY_ANALYSIS_URL:-http://${SECONDARY_HOST}:8100}"
fi

check_url() {
  local label="$1"
  local url="$2"
  local required="$3"
  local status

  if [ -z "$url" ]; then
    status="skipped"
  else
    status="$(curl -L -sS --connect-timeout 5 --max-time 10 -o "$TMP_BODY" -w '%{http_code}' "$url" 2>/dev/null || true)"
    status="${status:-000}"
  fi

  printf '%s\t%s\t%s\t%s\n' "$label" "$url" "$required" "$status"
}

CHECKS_FILE="$OUT_DIR/latest_checks.tsv"
: > "$CHECKS_FILE"
check_url "primary_platform" "${PRIMARY_PLATFORM_URL}/health" "true" >> "$CHECKS_FILE"
check_url "primary_collection" "${PRIMARY_COLLECTION_URL}/health" "true" >> "$CHECKS_FILE"
if [ -n "$PRIMARY_WEB_URL" ]; then
  check_url "primary_web" "${PRIMARY_WEB_URL}/" "false" >> "$CHECKS_FILE"
fi
if [ -n "$SECONDARY_COLLECTION_URL" ]; then
  check_url "secondary_collection" "${SECONDARY_COLLECTION_URL}/health" "$([ "$EXPECT_SECONDARY" = "1" ] && echo true || echo false)" >> "$CHECKS_FILE"
fi
if [ -n "$SECONDARY_ANALYSIS_URL" ]; then
  check_url "secondary_analysis" "${SECONDARY_ANALYSIS_URL}/health" "$([ "$EXPECT_SECONDARY" = "1" ] && echo true || echo false)" >> "$CHECKS_FILE"
fi

export JSON_OUT MD_OUT CHECKS_FILE PRIMARY_PLATFORM_URL PRIMARY_COLLECTION_URL PRIMARY_WEB_URL
export SECONDARY_COLLECTION_URL SECONDARY_ANALYSIS_URL EXPECT_SECONDARY
python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

checks = []
required_failures = []
warnings = []

for line in Path(os.environ["CHECKS_FILE"]).read_text(encoding="utf-8").splitlines():
    label, url, required, status = line.split("\t")
    ok = status == "200"
    item = {
        "label": label,
        "url": url,
        "required": required == "true",
        "status": status,
        "ok": ok,
    }
    checks.append(item)
    if item["required"] and not ok:
        required_failures.append(f"{label} returned {status} for {url}")
    elif url and not ok and status != "skipped":
        warnings.append(f"{label} returned {status} for {url}")

summary = {
    "kind": "ai_pms_cross_server_connectivity",
    "checked_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "status": "failed" if required_failures else "passed",
    "mode": {
        "expect_secondary": os.environ["EXPECT_SECONDARY"] == "1",
        "primary_platform_url": os.environ["PRIMARY_PLATFORM_URL"],
        "primary_collection_url": os.environ["PRIMARY_COLLECTION_URL"],
        "primary_web_url": os.environ["PRIMARY_WEB_URL"],
        "secondary_collection_url": os.environ["SECONDARY_COLLECTION_URL"],
        "secondary_analysis_url": os.environ["SECONDARY_ANALYSIS_URL"],
    },
    "checks": checks,
    "required_failures": required_failures,
    "warnings": warnings,
}

Path(os.environ["JSON_OUT"]).write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lines = [
    "# AI-PMS Cross Server Connectivity Report",
    "",
    f"- Status: `{summary['status']}`",
    f"- Checked at: `{summary['checked_at']}`",
    f"- Expect secondary: `{summary['mode']['expect_secondary']}`",
    "",
    "| Check | Required | HTTP | URL |",
    "|---|---:|---:|---|",
]
for check in checks:
    lines.append(f"| {check['label']} | {check['required']} | {check['status']} | `{check['url']}` |")
if required_failures:
    lines += ["", "## Required Failures", ""]
    lines += [f"- {failure}" for failure in required_failures]
if warnings:
    lines += ["", "## Warnings", ""]
    lines += [f"- {warning}" for warning in warnings]
Path(os.environ["MD_OUT"]).write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"cross_server_connectivity={summary['status']}")
print(f"json={os.environ['JSON_OUT']}")
print(f"markdown={os.environ['MD_OUT']}")
if required_failures:
    raise SystemExit(1)
PY

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="$ROOT_DIR/runtime/local_environment/latest_doctor.json"
REPORT_MD_PATH="$ROOT_DIR/runtime/local_environment/latest_doctor.md"

cd "$ROOT_DIR"

echo "Checking local environment doctor"

bash scripts/doctor_local_environment.sh >/tmp/aipms-local-environment-doctor.out
python3 -m json.tool "$REPORT_PATH" >/dev/null
test -f "$REPORT_MD_PATH"

rg -q 'local_environment_doctor' /tmp/aipms-local-environment-doctor.out "$REPORT_PATH" "$REPORT_MD_PATH"
rg -q 'markdown=' /tmp/aipms-local-environment-doctor.out
rg -q '# AI-PMS Local Environment Doctor' "$REPORT_MD_PATH"
rg -q 'web_vite_dependency' "$REPORT_PATH" "$REPORT_MD_PATH"
rg -q 'direct_apk_sha256' "$REPORT_PATH" "$REPORT_MD_PATH"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path

report = json.loads(Path("runtime/local_environment/latest_doctor.json").read_text(encoding="utf-8"))
assert report["kind"] == "local_environment_doctor"
assert report["overall_status"] in {"passed", "warning", "failed"}
assert report["required_failures"] == 0, report["required_failures"]
checks = {check["name"]: check for check in report["checks"]}
for required in (
    "drive_source_root",
    "dir_backend",
    "dir_collection_api",
    "dir_analysis_server",
    "dir_android_client",
    "dir_web_client",
    "backend_python",
    "collection_python",
    "analysis_python",
    "direct_apk",
    "direct_apk_sha256_file",
    "direct_apk_sha256",
    "script_verify_mvp_static.sh",
    "script_smoke_screen_design_ui.sh",
):
    assert checks[required]["status"] == "passed", (required, checks[required])

assert checks["web_vite_dependency"]["status"] in {"passed", "warning"}
PY

echo "local environment doctor smoke passed"

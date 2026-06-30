#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="$ROOT_DIR/runtime/public_handoff/latest_doctor.json"
REPORT_MD_PATH="$ROOT_DIR/runtime/public_handoff/latest_doctor.md"

cd "$ROOT_DIR"

echo "Checking public handoff doctor"

bash scripts/doctor_public_handoff.sh >/tmp/aipms-public-handoff-doctor.out
python3 -m json.tool "$REPORT_PATH" >/dev/null
test -f "$REPORT_MD_PATH"

rg -q 'public_handoff_doctor' /tmp/aipms-public-handoff-doctor.out "$REPORT_PATH" "$REPORT_MD_PATH"
rg -q 'markdown=' /tmp/aipms-public-handoff-doctor.out
rg -q '# AI-PMS Public Handoff Doctor' "$REPORT_MD_PATH"
rg -q 'required_failures' "$REPORT_MD_PATH"
rg -q 'RESTART_PUBLIC_TUNNELS=1 AIPMS_REFRESH_START_TUNNELS=1' /tmp/aipms-public-handoff-doctor.out "$REPORT_PATH" "$REPORT_MD_PATH"
rg -q 'AI-PMS-Recorder.apk' "$REPORT_PATH"
rg -q 'AI-PMS-requirements-v0.2.docx' "$REPORT_PATH"
rg -q 'requirements_docx_sha256' "$REPORT_PATH"
rg -q 'apk_alias_sha256' "$REPORT_PATH"
rg -q 'latest_public_smoke' "$REPORT_PATH"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path

report = json.loads(Path("runtime/public_handoff/latest_doctor.json").read_text(encoding="utf-8"))
assert report["kind"] == "public_handoff_doctor"
assert report["overall_status"] in {"passed", "warning", "failed"}
assert report["required_failures"] == 0, report["required_failures"]
checks = {check["name"]: check for check in report["checks"]}
for required in (
    "review_package_json",
    "execution_json",
    "apk_metadata_json",
    "requirements_manifest_json",
    "public_apk_alias",
    "public_requirements_docx",
    "requirements_docx_sha256",
    "apk_alias_sha256",
):
    assert checks[required]["status"] == "passed", (required, checks[required])
assert any("refresh_public_handoff_bundle" in item for item in report["recommendations"])
PY

echo "public handoff doctor smoke passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
REPORT="$DRIVE_ROOT/3. 포트폴리오 정리/AI_PMS_MVP_실행검증_포트폴리오.md"
SUMMARY_JSON="$ROOT_DIR/runtime/portfolio_evidence/latest_portfolio_evidence.json"

cd "$ROOT_DIR"

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing file: $file" >&2
    exit 1
  fi
}

require_text() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "missing $label in $file: $pattern" >&2
    exit 1
  fi
}

echo "Checking portfolio evidence bundle"
bash scripts/export_portfolio_evidence_bundle.sh >/tmp/aipms-portfolio-evidence.log

require_file "$REPORT"
require_file "$SUMMARY_JSON"

require_text "$REPORT" "AI-PMS MVP 실행검증 포트폴리오 근거" "portfolio report title"
require_text "$REPORT" "Project_ID" "Project_ID traceability"
require_text "$REPORT" "A-000 녹음 홈" "Android recorder-first screen"
require_text "$REPORT" "AI-PMS-Recorder.apk" "APK artifact"
require_text "$REPORT" "참석자 수동 선택 없음" "no manual attendee selection"
require_text "$REPORT" "release APK 생성" "release signing gap"
require_text "$REPORT" "실기기 녹음·업로드 E2E" "physical-device gap"
require_text "$REPORT" "smoke_screen_design_ui" "UI smoke evidence"
require_text "$REPORT" "execution.json" "execution manifest"

current_apk_sha="$(python3 - <<'PY'
import json
from pathlib import Path

print(json.loads(Path("web_client/public/downloads/android-apk.json").read_text(encoding="utf-8"))["sha256"])
PY
)"
require_text "$REPORT" "$current_apk_sha" "current APK hash"

python3 - <<'PY'
import json
from pathlib import Path

summary = json.loads(Path("runtime/portfolio_evidence/latest_portfolio_evidence.json").read_text(encoding="utf-8"))
apk = json.loads(Path("web_client/public/downloads/android-apk.json").read_text(encoding="utf-8"))
run = json.loads(Path("web_client/public/run/execution.json").read_text(encoding="utf-8"))
handoff = json.loads(Path("web_client/public/handoff/public-review-package.json").read_text(encoding="utf-8"))

assert summary["kind"] == "ai_pms_mvp_portfolio_evidence"
assert summary["apk"]["metadata_match"] is True
assert summary["apk"]["sha256"] == apk["sha256"]
assert summary["apk"]["sha256"] == run["android_apk"]["sha256"]
assert summary["apk"]["sha256"] == handoff["android_apk"]["sha256"]
assert "Project_ID" in summary["core_keys"]
assert summary["scope"] == "recorder_first_project_member_auto_distribution_mvp"
PY

if grep -Fq "f5ae983113556d5a1cb8fd536b38927240107b123cf13f6bace526d289668338" "$REPORT" "$SUMMARY_JSON"; then
  echo "stale APK hash found in portfolio evidence" >&2
  exit 1
fi

echo "portfolio evidence bundle smoke passed"

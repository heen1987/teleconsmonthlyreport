#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
APK_DIR="$DRIVE_ROOT/배포_APK"

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

echo "Checking Drive screen-design image set"
image_count="$(find "$DRIVE_ROOT/1. 화면설계서" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | wc -l | tr -d ' ')"
if [ "$image_count" -lt 10 ]; then
  echo "expected at least 10 screen-design images, found $image_count" >&2
  exit 1
fi
echo "screen-design images: $image_count"

WEB_MAIN="$ROOT_DIR/web_client/src/main.tsx"
WEB_CSS="$ROOT_DIR/web_client/src/styles.css"
ANDROID_MAIN="$ROOT_DIR/android_client/src/main/java/com/aipms/MainActivity.kt"

require_file "$WEB_MAIN"
require_file "$WEB_CSS"
require_file "$ANDROID_MAIN"

echo "Checking React Web screen-design markers"
for marker in \
  "WEB-01 워크스페이스" \
  "WEB-02 업무보드" \
  "WEB-03 문서공간" \
  "WEB-04 검토·승인" \
  "ADMIN-01 운영관리" \
  "APP-01~05" \
  "새싹SW" \
  "50명 SW개발회사" \
  "연매출" \
  "AI연구소" \
  "selectedProjectDetail" \
  "프로젝트 인력·투입" \
  "이메일 미등록" \
  "계획 M/M" \
  "배정원가" \
  "연봉 스냅샷" \
  "note-benchmark-workbench" \
  "프로젝트 회의 노트" \
  "AI 메모" \
  "수동 참석자 선택 없음" \
  "회의명, 안건, 키워드 검색" \
  "구간 01" \
  "프로젝트 기준 녹음 · 자동 배포" \
  "AI 요약" \
  "스크립트" \
  "app-flow-showcase" \
  "admin-showcase"
do
  require_text "$WEB_MAIN" "$marker" "React marker"
done

echo "Checking React Web style markers"
for marker in \
  ".screen-design-canvas" \
  ".browser-frame" \
  ".project-staffing-panel" \
  ".staffing-list" \
  ".note-benchmark-workbench" \
  ".note-transcript-pane" \
  ".note-ai-pane" \
  ".note-app-preview" \
  ".app-screen-strip" \
  ".mini-phone" \
  ".admin-metric-strip"
do
  require_text "$WEB_CSS" "$marker" "CSS marker"
done

echo "Checking Android recorder-first minimal UI markers"
for marker in \
  "screenDesignTraceMarkers" \
  "APP-01 로그인" \
  "APP-02 프로젝트 선택" \
  "APP-03 회의명" \
  "APP-04 녹음" \
  "APP-05 처리상태" \
  "AI-PMS Recorder" \
  "회의 녹음" \
  "회의명 또는 Meeting ID" \
  "recordButton = button(\"녹음 시작\")" \
  "uploadButton = button(\"업로드 및 분석 요청\")" \
  "statusCheckButton = button(\"처리상태 확인\")" \
  "actionRow(recordButton)" \
  "actionRow(uploadButton, statusCheckButton)" \
  "contentHost.addView(homeScreen())"
do
  require_text "$ANDROID_MAIN" "$marker" "Android marker"
done

for forbidden in \
  "buildSideMenu" \
  "menuItem(" \
  "toggleDrawer" \
  "drawerOpen" \
  "녹음 전 체크" \
  "업로드 후 자동 흐름" \
  "CLOVA Note처럼" \
  "Daglo처럼"
do
  if rg -F -q "$forbidden" "$ANDROID_MAIN"; then
    echo "Android recorder app must stay single-screen and explanation-free: $forbidden" >&2
    exit 1
  fi
done

echo "Checking Android recorder scope guard"
for forbidden in \
  "replaceMeetingAttendees" \
  "MeetingAttendeesReplaceRequest" \
  "MeetingAttendeeDto" \
  "attendee_user_ids" \
  "/attendees" \
  "CheckBox"
do
  if rg -q "$forbidden" "$ROOT_DIR/android_client/src/main/java"; then
    echo "Android recorder flow must not expose manual attendee selection or attendee-save API: $forbidden" >&2
    exit 1
  fi
done
require_text "$ROOT_DIR/android_client/README.md" "Android client does not include attendee-save API contracts" "Android README recorder scope guard"

echo "Checking direct APK handoff"
require_file "$APK_DIR/AI-PMS-Recorder.apk"
require_file "$APK_DIR/AI-PMS-Recorder.sha256"
require_file "$APK_DIR/apk_manifest.json"
require_file "$APK_DIR/README.md"
require_file "$APK_DIR/설치검증_리포트.md"
require_text "$APK_DIR/README.md" "프로젝트 구성원 자동 배포 대상" "direct APK guide project-member distribution"
require_text "$APK_DIR/설치검증_리포트.md" "AI-PMS Recorder APK 설치검증 리포트" "direct APK install report title"
require_text "$APK_DIR/설치검증_리포트.md" "Do not add a manual attendee selection step" "direct APK install report attendee guard"

(
  cd "$APK_DIR"
  shasum -a 256 -c AI-PMS-Recorder.sha256 >/dev/null
  python3 - <<'PY'
import hashlib
import json
import pathlib

apk = pathlib.Path("AI-PMS-Recorder.apk")
manifest = json.loads(pathlib.Path("apk_manifest.json").read_text())
sha = hashlib.sha256(apk.read_bytes()).hexdigest()
assert manifest["artifact_type"] == "android_apk"
assert manifest["responsive_layout"] is True
assert manifest["device_targets"] == ["phone", "tablet"]
assert apk.stat().st_size == manifest["size_bytes"]
assert sha == manifest["sha256"]
assert sha in pathlib.Path("README.md").read_text(encoding="utf-8")
assert sha in pathlib.Path("설치검증_리포트.md").read_text(encoding="utf-8")
PY
)

python3 - <<'PY'
import hashlib
import json
from pathlib import Path

root = Path.cwd()
apk = root / "web_client/public/downloads/AI-PMS-Recorder.apk"
metadata = json.loads((root / "web_client/public/downloads/android-apk.json").read_text(encoding="utf-8"))
sha = hashlib.sha256(apk.read_bytes()).hexdigest()
assert metadata["apk_alias"] == "AI-PMS-Recorder.apk"
assert metadata["layout"] == "responsive_phone_tablet"
assert metadata["sha256"] == sha
assert metadata["size_bytes"] == apk.stat().st_size
PY

if [ "${AIPMS_SCREEN_UI_BUILD:-0}" = "1" ]; then
  echo "Running optional Web and Android builds"
  (
    cd "$ROOT_DIR/web_client"
    npm run build
  )
  ANDROID_CLEAN_BUILD="${ANDROID_CLEAN_BUILD:-0}" bash "$ROOT_DIR/scripts/build_android_debug.sh"
fi

echo "screen-design UI smoke passed"

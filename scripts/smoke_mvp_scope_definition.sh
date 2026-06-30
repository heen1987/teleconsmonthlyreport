#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

REQUIREMENTS_DOC="docs/23_mvp_requirements_definition.md"

require_text() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "missing $label in $file: $pattern" >&2
    exit 1
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Fq "$pattern" "$file"; then
    echo "unexpected $label in $file: $pattern" >&2
    exit 1
  fi
}

test -f "$REQUIREMENTS_DOC" || {
  echo "missing MVP requirements definition: $REQUIREMENTS_DOC" >&2
  exit 1
}

echo "Checking MVP requirements definition"
for marker in \
  "구현/검증 범위" \
  "참석자 선택 필수화" \
  "화자 매핑" \
  "발언자/담당자 임의 추정" \
  "공개 회원가입" \
  "자동 확정" \
  "Project_ID" \
  "Meeting_ID" \
  "Scope Gate" \
  "배포 대상 자동 산정"
do
  require_text "$REQUIREMENTS_DOC" "$marker" "MVP requirements marker"
done

echo "Checking scope and backlog alignment"
for file in \
  docs/00_project_scope.md \
  docs/01_architecture.md \
  docs/02_mvp_backlog.md \
  docs/08_drive_based_reconfiguration.md \
  docs/15_mvp_first_implementation.md \
  docs/05_mac_mini_analysis_server.md \
  docs/18_part_handoff_drafts.md \
  README.md \
  analysis_server/README.md
do
  require_absent "$file" "화자 정리" "speaker-normalization wording"
  require_absent "$file" "speaker-label normalization" "speaker-label wording"
  require_absent "$file" "speaker normalization" "speaker normalization wording"
  require_absent "$file" "Store actual attendees" "attendee-required wording"
done

echo "Checking direct APK handoff guide alignment"
require_absent "../배포_APK/README.md" "4. 참석자를 선택합니다." "manual attendee install-guide step"
require_absent "../배포_APK/README.md" "8b8576072ab6e954816ea6e244641ab0d3ee455f772815199d003fa6fb36f6ea" "stale APK hash"
require_text "../배포_APK/README.md" "프로젝트 구성원 자동 배포 대상" "project-member auto distribution guide"
require_text scripts/install_android_public_debug_apk.sh "Do not add a manual attendee selection step" "install check attendee guard"
require_text scripts/install_android_public_debug_apk.sh "설치검증_리포트.md" "install markdown report"
python3 - <<'PY'
import hashlib
import json
from pathlib import Path

apk_dir = Path("../배포_APK")
apk = apk_dir / "AI-PMS-Recorder.apk"
sha_file = apk_dir / "AI-PMS-Recorder.sha256"
manifest = json.loads((apk_dir / "apk_manifest.json").read_text(encoding="utf-8"))
readme = (apk_dir / "README.md").read_text(encoding="utf-8")
report = (apk_dir / "설치검증_리포트.md").read_text(encoding="utf-8")
metadata = json.loads(Path("web_client/public/downloads/android-apk.json").read_text(encoding="utf-8"))

sha = hashlib.sha256(apk.read_bytes()).hexdigest()
assert sha in sha_file.read_text(encoding="utf-8")
assert manifest["sha256"] == sha
assert metadata["sha256"] == sha
assert manifest["size_bytes"] == apk.stat().st_size
assert metadata["size_bytes"] == apk.stat().st_size
assert sha in readme
assert sha in report
assert "project_only_recording_auto_project_member_distribution" == manifest["flow_policy"]
PY

echo "Checking analysis contract objective controls"
require_text contracts/analysis_result.schema.json "Do not infer speaker identity" "speaker inference guard"
require_text contracts/analysis_result.schema.json "Do not infer responsibility" "assignee inference guard"
require_text analysis_server/app/services/llm.py "Do not infer speakers, assignees, responsibility, or attendance" "analysis prompt guard"
require_text backend/app/services/llm.py "Do not infer assignees, responsibility, attendance, or speaker identity" "backend prompt guard"
require_text web_client/src/main.tsx "회의명, 안건, 키워드 검색" "content-centered search label"
require_text web_client/src/main.tsx "구간 01" "content-centered transcript label"
require_text android_client/src/main/java/com/aipms/MainActivity.kt "recordButton = button(\"녹음 시작\")" "recorder-first Android primary action"

echo "MVP scope definition smoke passed"

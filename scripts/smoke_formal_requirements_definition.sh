#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
PYTHON_BIN="${AIPMS_PYTHON:-/Users/ppp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
RENDER_DOCX="/Users/ppp/.codex/plugins/cache/openai-primary-runtime/documents/26.623.12021/skills/documents/render_docx.py"
LOCAL_MD="$ROOT_DIR/docs/23_mvp_requirements_definition.md"
DRIVE_MD="$DRIVE_ROOT/2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md"
DOCX="$DRIVE_ROOT/2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx"
RENDER_DIR="$ROOT_DIR/runtime/formal_requirements_render_smoke"

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

require_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Fq -- "$pattern" "$file"; then
    echo "unexpected $label in $file: $pattern" >&2
    exit 1
  fi
}

echo "Checking formal requirements definition"
"$PYTHON_BIN" scripts/export_formal_requirements_definition.py >/tmp/aipms-formal-requirements.log

require_file "$LOCAL_MD"
require_file "$DRIVE_MD"
require_file "$DOCX"

for marker in \
  "AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서" \
  "v0.2" \
  "앱은 녹음 중심" \
  "시스템 관리자 요구사항" \
  "배포 대상 자동 산정" \
  "요구사항 추적성 매트릭스" \
  "MVP 범위 통제 기준(Scope Gate)" \
  "참석자 선택 필수화" \
  "화자 매핑" \
  "발언자·담당자 임의 추정 없이 결과 생성" \
  "Project_ID" \
  "Meeting_ID"
do
  require_text "$LOCAL_MD" "$marker" "formal requirements marker"
  require_text "$DRIVE_MD" "$marker" "Drive formal requirements marker"
done

require_absent "$LOCAL_MD" "3.3. 프로젝트 관리자 요구사항" "duplicate/wrong admin section title"
require_absent "$LOCAL_MD" "-   다 음" "page marker residue"
require_absent "$LOCAL_MD" "외부 이메일로 배포" "MVP external-recipient distribution wording"

"$PYTHON_BIN" - <<'PY'
from docx import Document
from pathlib import Path

docx_path = Path("../2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx")
doc = Document(docx_path)
text = "\n".join(paragraph.text for paragraph in doc.paragraphs)
assert len(doc.paragraphs) >= 70
assert len(doc.tables) >= 20
for marker in (
    "AI-PMS 기반",
    "3.3. 시스템 관리자 요구사항",
    "8.3. 요구사항 추적성 매트릭스",
    "9. MVP 범위 통제 기준(Scope Gate)",
):
    assert marker in text, marker
assert "3.3. 프로젝트 관리자 요구사항" not in text
PY

rm -rf "$RENDER_DIR"
"$PYTHON_BIN" "$RENDER_DOCX" "$DOCX" --output_dir "$RENDER_DIR" --emit_pdf >/tmp/aipms-formal-requirements-render.log

page_count="$(find "$RENDER_DIR" -maxdepth 1 -type f -name 'page-*.png' | wc -l | tr -d ' ')"
if [ "$page_count" -lt 10 ]; then
  echo "unexpected rendered page count: $page_count" >&2
  exit 1
fi

echo "formal requirements definition smoke passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_DIR="$ROOT_DIR/web_client/public/requirements"
MANIFEST="$PUBLIC_DIR/requirements.json"
DOCX="$PUBLIC_DIR/AI-PMS-requirements-v0.2.docx"
MARKDOWN="$PUBLIC_DIR/AI-PMS-requirements-v0.2.md"

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

echo "Checking requirements public publication"
bash scripts/publish_requirements_documents.sh >/tmp/aipms-requirements-publication.log

require_file "$MANIFEST"
require_file "$DOCX"
require_file "$MARKDOWN"

require_text "$MARKDOWN" "AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서" "requirements title"
require_text "$MARKDOWN" "MVP 범위 통제 기준" "scope gate"
require_text "$MARKDOWN" "프로젝트 참여인원 기준으로 배포 대상 자동 산정" "project-member distribution"
require_text "$MARKDOWN" "발언자/담당자 임의 추정" "speaker/assignee exclusion"
require_text "$MANIFEST" "requirements_documents" "requirements manifest kind"
require_text "$MANIFEST" "AI-PMS-requirements-v0.2.docx" "requirements DOCX public file"
require_text "$MANIFEST" "no mandatory attendee selection" "scope control"

python3 - <<'PY'
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


manifest = json.loads(Path("web_client/public/requirements/requirements.json").read_text(encoding="utf-8"))
docx = Path("web_client/public/requirements/AI-PMS-requirements-v0.2.docx")
markdown = Path("web_client/public/requirements/AI-PMS-requirements-v0.2.md")

assert manifest["kind"] == "requirements_documents"
assert manifest["version"] == "v0.2"
assert manifest["public_files"]["docx"]["sha256"] == sha256(docx)
assert manifest["public_files"]["markdown"]["sha256"] == sha256(markdown)
assert docx.stat().st_size > 20_000
assert markdown.stat().st_size > 10_000
PY

echo "requirements public publication smoke passed"

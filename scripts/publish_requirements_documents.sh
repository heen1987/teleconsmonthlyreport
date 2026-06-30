#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
PUBLIC_DIR="$ROOT_DIR/web_client/public/requirements"
SOURCE_DOCX="$DRIVE_ROOT/2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx"
SOURCE_MD="$DRIVE_ROOT/2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md"
PUBLIC_DOCX_NAME="AI-PMS-requirements-v0.2.docx"
PUBLIC_MD_NAME="AI-PMS-requirements-v0.2.md"
PUBLIC_MANIFEST="$PUBLIC_DIR/requirements.json"

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing requirements source: $file" >&2
    echo "Run scripts/export_formal_requirements_definition.py first." >&2
    exit 1
  fi
}

require_file "$SOURCE_DOCX"
require_file "$SOURCE_MD"

mkdir -p "$PUBLIC_DIR"

cp "$SOURCE_DOCX" "$PUBLIC_DIR/$PUBLIC_DOCX_NAME"
cp "$SOURCE_MD" "$PUBLIC_DIR/$PUBLIC_MD_NAME"

export SOURCE_DOCX SOURCE_MD PUBLIC_DIR PUBLIC_DOCX_NAME PUBLIC_MD_NAME PUBLIC_MANIFEST

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


source_docx = Path(os.environ["SOURCE_DOCX"])
source_md = Path(os.environ["SOURCE_MD"])
public_dir = Path(os.environ["PUBLIC_DIR"])
docx_name = os.environ["PUBLIC_DOCX_NAME"]
md_name = os.environ["PUBLIC_MD_NAME"]
manifest = Path(os.environ["PUBLIC_MANIFEST"])
public_docx = public_dir / docx_name
public_md = public_dir / md_name

metadata = {
    "kind": "requirements_documents",
    "project": "AI-PMS",
    "version": "v0.2",
    "published_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "title": "AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서",
    "source_paths": {
        "docx": str(source_docx),
        "markdown": str(source_md),
    },
    "public_files": {
        "docx": {
            "file_name": docx_name,
            "path": str(public_docx),
            "sha256": sha256(public_docx),
            "size_bytes": public_docx.stat().st_size,
        },
        "markdown": {
            "file_name": md_name,
            "path": str(public_md),
            "sha256": sha256(public_md),
            "size_bytes": public_md.stat().st_size,
        },
    },
    "scope_controls": [
        "recording-first Android app",
        "project-only selection before upload",
        "project-member automatic distribution",
        "no mandatory attendee selection",
        "no speaker mapping",
        "no AI auto-confirmation",
    ],
}

manifest.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print(f"Published requirements DOCX: {public_docx}")
print(f"Published requirements Markdown: {public_md}")
print(f"Published requirements manifest: {manifest}")
PY

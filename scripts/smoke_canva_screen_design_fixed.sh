#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PPTX="$ROOT_DIR/outputs/AI-PMS_MEETFLOW_screen_design_fixed.pptx"
MANIFEST="$ROOT_DIR/outputs/AI-PMS_MEETFLOW_screen_design_fixed_manifest.json"
PREVIEW_DIR="$ROOT_DIR/outputs/screen_design_fixed_preview"
HANDOFF_JSON="$ROOT_DIR/web_client/public/handoff/canva-screen-design-fixed.json"
HANDOFF_DOC="$ROOT_DIR/docs/26_canva_screen_design_fixed_handoff.md"
INSPECT_FILE="$ROOT_DIR/outputs/AI-PMS_MEETFLOW_screen_design_fixed.pptx.inspect.ndjson"

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing file: $file" >&2
    exit 1
  fi
}

require_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    echo "missing directory: $dir" >&2
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

require_file "$PPTX"
require_file "$MANIFEST"
require_file "$HANDOFF_JSON"
require_file "$HANDOFF_DOC"
require_file "$INSPECT_FILE"
require_dir "$PREVIEW_DIR"

require_text "$HANDOFF_DOC" "Canva connector returned \`quota_exceeded\`" "Canva quota fallback note"
require_text "$HANDOFF_DOC" "The app is recording-first" "recording-first rule"
require_text "$HANDOFF_DOC" "project-only for meeting" "project-only override"
require_text "$HANDOFF_DOC" "Attendee selection is not a" "attendee-selection exclusion"
require_text "$INSPECT_FILE" "MEETFLOW" "PPTX inspect brand marker"
require_text "$INSPECT_FILE" "회의 녹음" "PPTX inspect recording marker"
require_text "$INSPECT_FILE" "프로젝트 선택" "PPTX inspect project marker"

python3 - <<'PY' "$PPTX" "$MANIFEST" "$HANDOFF_JSON" "$PREVIEW_DIR"
import json
import pathlib
import sys
import zipfile

pptx = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
handoff_path = pathlib.Path(sys.argv[3])
preview_dir = pathlib.Path(sys.argv[4])

with zipfile.ZipFile(pptx) as archive:
    bad_entry = archive.testzip()
    if bad_entry is not None:
        raise SystemExit(f"corrupt pptx entry: {bad_entry}")
    slides = [
        name
        for name in archive.namelist()
        if name.startswith("ppt/slides/slide") and name.endswith(".xml")
    ]
    media = [
        name
        for name in archive.namelist()
        if name.startswith("ppt/media/")
    ]
    assert len(slides) == 12, f"expected 12 slides, got {len(slides)}"
    assert len(media) >= 8, f"expected embedded screen images, got {len(media)} media files"

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
handoff = json.loads(handoff_path.read_text(encoding="utf-8"))

assert manifest["slides"] == 12
assert pathlib.Path(manifest["finalPptx"]).samefile(pptx)
assert pathlib.Path(manifest["previewDir"]).samefile(preview_dir)
for key in [
    "app_recording_first",
    "project_only_no_attendee_selection",
    "web_review_approval_distribution_pms_reflection",
]:
    assert key in manifest["constraints"], f"missing manifest constraint: {key}"

assert handoff["artifact_id"] == "canva-screen-design-fixed"
assert handoff["brand"] == "MEETFLOW"
assert handoff["status"] == "fixed_local_pptx_due_canva_quota_exceeded"
assert pathlib.Path(handoff["final_pptx"]).samefile(pptx)
assert pathlib.Path(handoff["manifest"]).samefile(manifest_path)
assert pathlib.Path(handoff["preview_dir"]).samefile(preview_dir)
assert len(handoff["slides"]) == 12
for key in [
    "app_recording_first",
    "project_only_no_attendee_selection",
    "automatic_distribution_to_project_members",
    "ai_no_speaker_or_owner_inference",
]:
    assert key in handoff["fixed_rules"], f"missing handoff rule: {key}"

pngs = sorted(preview_dir.glob("slide-*.png"))
layouts = sorted(preview_dir.glob("slide-*.layout.json"))
assert len(pngs) == 12, f"expected 12 preview PNGs, got {len(pngs)}"
assert len(layouts) == 12, f"expected 12 layout JSON files, got {len(layouts)}"
assert (preview_dir / "deck-montage.webp").is_file()
for layout in layouts:
    json.loads(layout.read_text(encoding="utf-8"))

print("canva screen-design fixed smoke passed")
print(f"pptx={pptx}")
print(f"slides={len(slides)} preview_pngs={len(pngs)} layouts={len(layouts)}")
PY

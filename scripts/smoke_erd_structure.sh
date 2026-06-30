#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DRIVE_ROOT="$(cd "${APP_ROOT}/.." && pwd)"

ERD_DOC="${DRIVE_ROOT}/개요/AI_PMS_ERD_구조.md"
ERD_MMD="${DRIVE_ROOT}/개요/diagrams/19_ai_pms_integrated_erd.mmd"
LOCAL_DOC="${APP_ROOT}/docs/21_erd_structure.md"
PLATFORM_SCHEMA="${APP_ROOT}/backend/schema.sql"
COLLECTION_SCHEMA="${APP_ROOT}/collection_api/schema.sql"
ROOT_README="${DRIVE_ROOT}/README.md"
OVERVIEW_README="${DRIVE_ROOT}/개요/README.md"

fail() {
  echo "ERD smoke failed: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing file: ${path}"
}

require_marker() {
  local path="$1"
  local marker="$2"
  rg -q --fixed-strings "${marker}" "${path}" || fail "missing marker '${marker}' in ${path}"
}

require_file "${ERD_DOC}"
require_file "${ERD_MMD}"
require_file "${LOCAL_DOC}"
require_file "${PLATFORM_SCHEMA}"
require_file "${COLLECTION_SCHEMA}"

require_marker "${ERD_MMD}" "erDiagram"
require_marker "${ERD_DOC}" "Platform DB"
require_marker "${ERD_DOC}" "Collection DB"
require_marker "${ERD_DOC}" "External ERP/HCM"
require_marker "${ROOT_README}" "개요/AI_PMS_ERD_구조.md"
require_marker "${OVERVIEW_README}" "diagrams/19_ai_pms_integrated_erd.mmd"
require_marker "${LOCAL_DOC}" "backend/schema.sql"
require_marker "${LOCAL_DOC}" "collection_api/schema.sql"

for marker in \
  "PROJECTS ||--o{ MEETINGS" \
  "MEETINGS ||--o{ MEETING_ANALYSES" \
  "MEETING_ANALYSES ||--o{ TASKS" \
  "MEETING_ANALYSES ||--o{ RESOURCE_DEMANDS" \
  "RESOURCE_DEMANDS ||--o{ RESOURCE_ALLOCATIONS" \
  "RESOURCE_ALLOCATIONS ||--o{ RESOURCE_USAGE_ENTRIES" \
  "RESOURCE_USAGE_ENTRIES ||--o{ PROJECT_COST_CANDIDATES" \
  "PROJECT_COST_CANDIDATES ||--o{ PROJECT_COST_HANDOFFS" \
  "COLLECTION_UPLOAD_SESSIONS ||--o{ COLLECTION_AUDIO_ASSETS" \
  "COLLECTION_ANALYSIS_JOBS ||--o| MEETING_ANALYSES"; do
  require_marker "${ERD_MMD}" "${marker}"
done

schema_tables="$(
  rg -No 'CREATE TABLE IF NOT EXISTS [a-z_][a-z0-9_]*' "${PLATFORM_SCHEMA}" "${COLLECTION_SCHEMA}" \
    | sed -E 's/.*CREATE TABLE IF NOT EXISTS ([a-z_][a-z0-9_]*)/\1/' \
    | sort -u
)"

while IFS= read -r table_name; do
  [[ -n "${table_name}" ]] || continue
  table_marker="$(printf '%s' "${table_name}" | tr '[:lower:]' '[:upper:]')"
  rg -q "^  ${table_marker}[[:space:]]+\\{" "${ERD_MMD}" \
    || fail "schema table missing from ERD: ${table_name}"
done <<< "${schema_tables}"

for planned_table in \
  CONTRACTS \
  PROJECT_BUDGETS \
  WBS_ITEMS \
  DOCUMENTS \
  NOTIFICATIONS \
  EXTERNAL_SYSTEM_MAPPINGS \
  ACCESS_POLICIES; do
  rg -q "^  ${planned_table}[[:space:]]+\\{" "${ERD_MMD}" \
    || fail "planned table missing from ERD: ${planned_table}"
done

if command -v mmdc >/dev/null 2>&1; then
  tmp_svg="${TMPDIR:-/tmp}/ai_pms_integrated_erd.svg"
  mmdc -i "${ERD_MMD}" -o "${tmp_svg}" >/dev/null
  [[ -s "${tmp_svg}" ]] || fail "Mermaid render output is empty"
  echo "Mermaid render check: ${tmp_svg}"
else
  echo "Mermaid render check skipped: mmdc is not installed"
fi

echo "ERD smoke passed"

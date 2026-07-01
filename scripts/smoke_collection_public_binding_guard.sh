#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

rg -q 'COLLECTION_BIND_HOST:-127\.0\.0\.1' scripts/run_collection_api.sh
rg -q 'AIPMS_COLLECTION_ALLOW_PUBLIC_BIND' scripts/run_collection_api.sh scripts/windows_run_collection_api.ps1 collection_api/.env.example README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'Refusing to bind Collection API to a public interface' scripts/run_collection_api.sh scripts/windows_run_collection_api.ps1
rg -q 'COLLECTION_INTERNAL_API_SECRET.*INTERNAL_SECRET' scripts/generate_prod_secrets.sh
rg -q 'Depends\(require_user_or_internal_client\)' collection_api/app/routers/collection.py
rg -q 'Depends\(require_internal_client\)' collection_api/app/routers/collection.py

if rg -q 'uvicorn app\.main:app --host 0\.0\.0\.0 --port 8200' scripts/run_collection_api.sh scripts/windows_run_collection_api.ps1; then
  echo "Collection API run scripts must not default to 0.0.0.0:8200." >&2
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  listen_output="$(lsof -nP -iTCP:8200 -sTCP:LISTEN 2>/dev/null || true)"
  if printf '%s\n' "$listen_output" | grep -E 'TCP (\*|0\.0\.0\.0|\[::\]):8200 ' >/dev/null; then
    echo "Collection API is currently listening on a public interface:" >&2
    printf '%s\n' "$listen_output" >&2
    exit 1
  fi
fi

echo "collection public binding guard passed"

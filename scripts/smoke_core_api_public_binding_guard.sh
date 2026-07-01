#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

rg -q 'PLATFORM_BIND_HOST:-127\.0\.0\.1' scripts/run_platform_backend.sh
rg -q 'ANALYSIS_BIND_HOST:-127\.0\.0\.1' scripts/run_analysis_server.sh
rg -q 'AIPMS_PLATFORM_ALLOW_PUBLIC_BIND' scripts/run_platform_backend.sh scripts/windows_run_platform_backend.ps1 backend/.env.example README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND' scripts/run_analysis_server.sh scripts/windows_run_analysis_server.ps1 analysis_server/.env.example README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'Refusing to bind Platform API to a public interface' scripts/run_platform_backend.sh scripts/windows_run_platform_backend.ps1
rg -q 'Refusing to bind Analysis server to a public interface' scripts/run_analysis_server.sh scripts/windows_run_analysis_server.ps1

if rg -q 'uvicorn app\.main:app --host 0\.0\.0\.0 --port 8000' scripts/run_platform_backend.sh scripts/windows_run_platform_backend.ps1; then
  echo "Platform API run scripts must not default to 0.0.0.0:8000." >&2
  exit 1
fi

if rg -q 'uvicorn app\.main:app --host 0\.0\.0\.0 --port 8100' scripts/run_analysis_server.sh scripts/windows_run_analysis_server.ps1; then
  echo "Analysis server run scripts must not default to 0.0.0.0:8100." >&2
  exit 1
fi

env_file_value() {
  local path="$1"
  local key="$2"
  if [ -f "$path" ]; then
    awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2) }' "$path" | tail -1
  fi
}

check_port_not_public() {
  local label="$1"
  local port="$2"
  local allow_public="${3:-0}"

  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi

  local listen_output
  listen_output="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if printf '%s\n' "$listen_output" | grep -E "TCP (\\*|0\\.0\\.0\\.0|\\[::\\]):${port} " >/dev/null; then
    if [ "$allow_public" = "1" ]; then
      echo "$label public binding is intentionally allowed for this runtime:"
      printf '%s\n' "$listen_output"
      return 0
    fi
    echo "$label is currently listening on a public interface:" >&2
    printf '%s\n' "$listen_output" >&2
    exit 1
  fi
}

check_port_not_public "Platform API" 8000
analysis_allow_public="$(env_file_value analysis_server/.env AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND)"
check_port_not_public "Analysis server" 8100 "${analysis_allow_public:-0}"

echo "core API public binding guard passed"

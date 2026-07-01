#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    return 1
  fi
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

print_service() {
  local label="$1"
  local service="$2"
  local suffix="${3:-}"
  local url="${4:-}"
  if [ -z "$url" ]; then
    url="$(extract_url "$service" || true)"
  fi
  if [ -n "$url" ]; then
    printf "%s:\n  %s%s\n" "$label" "$url" "$suffix"
  else
    printf "%s:\n  not running; check %s/%s.log\n" "$label" "$TUNNEL_DIR" "$service"
  fi
}

print_platform_server() {
  local url="${AIPMS_PUBLIC_PLATFORM_URL:-${AIPMS_PLATFORM_API_URL:-${AIPMS_PLATFORM_URL:-}}}"
  if [ -n "$url" ]; then
    printf "Platform API health:\n  %s/health\n" "${url%/}"
    printf "Platform API docs:\n  %s/docs\n" "${url%/}"
  else
    printf "Platform API:\n  not configured; set AIPMS_PLATFORM_URL or AIPMS_PLATFORM_API_URL to the Platform server URL\n"
  fi
}

cat <<EOF
AI-PMS public tunnel URLs

EOF
print_service "Web client" "web" "" "${AIPMS_PUBLIC_WEB_URL:-${AIPMS_GITHUB_PAGES_URL:-}}"
print_platform_server
print_service "Collection API health" "collection" "/health" "${AIPMS_PUBLIC_COLLECTION_URL:-}"
print_service "Collection API docs" "collection" "/docs" "${AIPMS_PUBLIC_COLLECTION_URL:-}"
print_service "Integrated analysis worker health" "collection" "/health" "${AIPMS_PUBLIC_COLLECTION_URL:-}"
print_service "Integrated analysis worker docs" "collection" "/docs" "${AIPMS_PUBLIC_COLLECTION_URL:-}"

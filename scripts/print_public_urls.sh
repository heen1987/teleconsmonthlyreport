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
  local url
  if url="$(extract_url "$service")" && [ -n "$url" ]; then
    printf "%s:\n  %s%s\n" "$label" "$url" "$suffix"
  else
    printf "%s:\n  not running; check %s/%s.log\n" "$label" "$TUNNEL_DIR" "$service"
  fi
}

cat <<EOF
AI-PMS public tunnel URLs

EOF
print_service "Web client" "web" ""
print_service "Platform API health" "platform" "/health"
print_service "Platform API docs" "platform" "/docs"
print_service "Collection API health" "collection" "/health"
print_service "Collection API docs" "collection" "/docs"
print_service "Analysis server health" "analysis" "/health"
print_service "Analysis server docs" "analysis" "/docs"

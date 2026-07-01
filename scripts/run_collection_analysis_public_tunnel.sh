#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
COLLECTION_PORT="${AIPMS_COLLECTION_PORT:-8200}"
COLLECTION_HEALTH_URL="http://127.0.0.1:${COLLECTION_PORT}/health"
RESTART_PUBLIC_TUNNELS="${RESTART_PUBLIC_TUNNELS:-0}"

mkdir -p "$TUNNEL_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

screen_session_names() {
  local name="$1"
  screen -ls 2>/dev/null | awk -v name="$name" '$1 ~ ("\\." name "$") { print $1 }' || true
}

stop_screen_sessions() {
  local name="$1"
  local session
  while read -r session; do
    [ -n "$session" ] && screen -S "$session" -X quit || true
  done < <(screen_session_names "$name")
}

latest_tunnel_url() {
  local log_file="$TUNNEL_DIR/collection.log"
  [ -f "$log_file" ] || return 1
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" 2>/dev/null | tail -1
}

wait_http_200() {
  local url="$1"
  local label="$2"
  local status
  for _ in $(seq 1 30); do
    status="$(curl -L -sS --connect-timeout 5 --max-time 10 -o /tmp/aipms-collection-tunnel-check.out -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [ "$status" = "200" ]; then
      echo "$label ready: $url"
      return 0
    fi
    sleep 2
  done
  echo "$label did not become ready: $url" >&2
  cat /tmp/aipms-collection-tunnel-check.out >&2 || true
  return 1
}

require_command cloudflared
require_command screen
require_command curl

wait_http_200 "$COLLECTION_HEALTH_URL" "Local Collection API"

screen_name="aipms-tunnel-collection"
log_file="$TUNNEL_DIR/collection.log"

if [ "$RESTART_PUBLIC_TUNNELS" = "1" ]; then
  stop_screen_sessions "$screen_name"
fi

if ! screen_session_names "$screen_name" | grep -q .; then
  : > "$log_file"
  screen -dmS "$screen_name" zsh -lc "cd '$ROOT_DIR' && exec cloudflared tunnel --url http://127.0.0.1:${COLLECTION_PORT} --no-autoupdate > '$log_file' 2>&1"
fi

collection_url=""
for _ in $(seq 1 20); do
  collection_url="$(latest_tunnel_url || true)"
  [ -n "$collection_url" ] && break
  sleep 2
done

if [ -z "$collection_url" ]; then
  echo "Timed out waiting for Collection tunnel URL. Log follows:" >&2
  cat "$log_file" >&2 || true
  exit 1
fi

wait_http_200 "$collection_url/health" "Public Collection API"

cat <<EOF
Collection/Analysis public tunnel is ready.

Collection API:
  $collection_url

Android public build:
  AIPMS_PLATFORM_API_URL=https://<platform-server-url> AIPMS_PUBLIC_COLLECTION_URL=$collection_url bash scripts/build_android_public_debug.sh

Repository variable to update if this URL should be shared:
  AIPMS_COLLECTION_PUBLIC_URL=$collection_url
EOF

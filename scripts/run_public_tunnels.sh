#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
RESTART_PUBLIC_TUNNELS="${RESTART_PUBLIC_TUNNELS:-0}"
RESTART_WEB_FOR_PUBLIC="${RESTART_WEB_FOR_PUBLIC:-1}"

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

service_health() {
  local port="$1"
  curl -sS -o /tmp/aipms-public-local-health.json -w '%{http_code}' "http://127.0.0.1:$port/health"
}

ensure_local_service() {
  local label="$1"
  local port="$2"
  local status
  status="$(service_health "$port" || true)"
  if [ "$status" != "200" ]; then
    echo "$label is not healthy on 127.0.0.1:$port. Start the base service first." >&2
    exit 1
  fi
}

start_tunnel() {
  local service="$1"
  local port="$2"
  local screen_name="aipms-tunnel-$service"
  local log_file="$TUNNEL_DIR/$service.log"

  if [ "$RESTART_PUBLIC_TUNNELS" = "1" ]; then
    stop_screen_sessions "$screen_name"
  fi

  if screen_session_names "$screen_name" | grep -q .; then
    return
  fi

  : > "$log_file"
  screen -dmS "$screen_name" zsh -lc "cd '$ROOT_DIR' && exec cloudflared tunnel --url http://127.0.0.1:$port --no-autoupdate > '$log_file' 2>&1"
}

wait_for_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  local url=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    url="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" 2>/dev/null | tail -1 || true)"
    if [ -n "$url" ]; then
      echo "$url"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for $service tunnel URL. Log follows:" >&2
  cat "$log_file" >&2 || true
  return 1
}

wait_for_web() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sS -o /tmp/aipms-public-web-local.html -w '%{http_code}' "http://127.0.0.1:3000/" | grep -q '^200$'; then
      return 0
    fi
    sleep 2
  done
  echo "Web client did not become healthy on 127.0.0.1:3000." >&2
  return 1
}

require_command cloudflared
require_command screen

ensure_local_service "Platform API" 8000
ensure_local_service "Collection API" 8200
ensure_local_service "Analysis server" 8100

start_tunnel platform 8000
start_tunnel collection 8200
start_tunnel analysis 8100

platform_url="$(wait_for_url platform)"
collection_url="$(wait_for_url collection)"
analysis_url="$(wait_for_url analysis)"

if [ "$RESTART_WEB_FOR_PUBLIC" = "1" ]; then
  stop_screen_sessions "aipms-web"
  screen -dmS aipms-web zsh -lc "cd '$ROOT_DIR/web_client' && VITE_API_BASE='$platform_url' exec npm run dev -- --host 0.0.0.0 --port 3000 --cors"
  wait_for_web
fi

start_tunnel web 3000
web_url="$(wait_for_url web)"

cat <<EOF
AI-PMS public tunnels are ready.

Web:
  $web_url

Platform API:
  $platform_url/docs

Collection API:
  $collection_url/docs

Analysis server:
  $analysis_url/docs

Build public Android APK:
  AIPMS_PUBLIC_PLATFORM_URL=$platform_url AIPMS_PUBLIC_COLLECTION_URL=$collection_url bash scripts/build_android_public_debug.sh
EOF

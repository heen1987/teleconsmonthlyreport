#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${AIPMS_CF_CONFIG:-$ROOT_DIR/runtime/cloudflare_named_tunnel/config.yml}"
LOG_FILE="${AIPMS_CF_LOG:-$ROOT_DIR/runtime/cloudflare_named_tunnel/named-tunnel.log}"
SCREEN_NAME="${AIPMS_CF_SCREEN_NAME:-aipms-named-tunnel}"
RESTART_NAMED_TUNNEL="${RESTART_NAMED_TUNNEL:-0}"

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

check_url() {
  local label="$1"
  local url="$2"
  local status
  status="$(curl -sS -o /tmp/aipms-named-tunnel-health.txt -w '%{http_code}' "$url" || true)"
  if [ "$status" != "200" ]; then
    echo "$label is not ready: HTTP $status ($url)" >&2
    exit 1
  fi
}

require_command cloudflared
require_command screen

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing named tunnel config: $CONFIG_FILE" >&2
  echo "Run: bash scripts/prepare_cloudflare_named_tunnel.sh" >&2
  exit 1
fi

check_url "Web client" "http://127.0.0.1:3000/"
check_url "Platform API" "http://127.0.0.1:8000/health"
check_url "Collection API" "http://127.0.0.1:8200/health"
check_url "Analysis server" "http://127.0.0.1:8100/health"

mkdir -p "$(dirname "$LOG_FILE")"

if [ "$RESTART_NAMED_TUNNEL" = "1" ]; then
  stop_screen_sessions "$SCREEN_NAME"
fi

if screen_session_names "$SCREEN_NAME" | grep -q .; then
  echo "Cloudflare named tunnel is already running in screen session: $SCREEN_NAME"
  exit 0
fi

: > "$LOG_FILE"
screen -dmS "$SCREEN_NAME" zsh -lc "cd '$ROOT_DIR' && exec cloudflared tunnel --config '$CONFIG_FILE' run > '$LOG_FILE' 2>&1"

echo "Cloudflare named tunnel started in screen session: $SCREEN_NAME"
echo "Log: $LOG_FILE"

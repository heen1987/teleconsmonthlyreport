#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/runtime/lan_execution"
RESTART_LAN_STACK="${RESTART_LAN_STACK:-0}"
LAN_STACK_REUSE_HEALTH_CHECK="${AIPMS_LAN_STACK_REUSE_HEALTH_CHECK:-1}"
WEB_PORT="${AIPMS_WEB_PORT:-3000}"

mkdir -p "$LOG_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

detect_lan_ip() {
  if [ -n "${LAN_IP:-}" ]; then
    printf '%s\n' "$LAN_IP"
    return 0
  fi

  local iface ip
  for iface in en1 en0; do
    if ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"; then
      if [ -n "$ip" ]; then
        printf '%s\n' "$ip"
        return 0
      fi
    fi
  done

  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{ print $1 }' || true)"
    if [ -n "$ip" ]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    ifconfig | awk '/inet / && $2 !~ /^127\./ { print $2; exit }'
    return 0
  fi

  return 1
}

shell_quote() {
  printf '%q' "$1"
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

http_ok() {
  local url="$1"
  local output="$LOG_DIR/reuse_check.body"
  local status

  status="$(curl -sS --connect-timeout 3 --max-time 8 -o "$output" -w '%{http_code}' "$url" || true)"
  [ "$status" = "200" ]
}

start_screen() {
  local name="$1"
  local command="$2"
  local health_url="${3:-}"
  local log_file="$LOG_DIR/$name.log"

  if [ "$RESTART_LAN_STACK" = "1" ]; then
    stop_screen_sessions "$name"
  fi

  if screen_session_names "$name" | grep -q .; then
    if [ "$LAN_STACK_REUSE_HEALTH_CHECK" = "1" ] && [ -n "$health_url" ]; then
      if http_ok "$health_url"; then
        return 0
      fi
      echo "Existing $name screen is stale. Restarting session." >&2
      stop_screen_sessions "$name"
    else
      return 0
    fi
  fi

  : > "$log_file"
  screen -dmS "$name" bash -lc "cd $(shell_quote "$ROOT_DIR") && $command > $(shell_quote "$log_file") 2>&1"
}

wait_http() {
  local label="$1"
  local url="$2"
  local output="$LOG_DIR/${label// /_}.body"
  local status=""

  for _ in $(seq 1 60); do
    status="$(curl -sS --connect-timeout 3 --max-time 8 -o "$output" -w '%{http_code}' "$url" || true)"
    if [ "$status" = "200" ]; then
      printf "%s: %s\n" "$label" "$url"
      return 0
    fi
    sleep 2
  done

  echo "$label did not become ready: $url" >&2
  cat "$output" >&2 || true
  return 1
}

require_command screen
require_command curl

LAN_IP="$(detect_lan_ip)"
if [ -z "$LAN_IP" ]; then
  echo "LAN IP not found. Set LAN_IP manually." >&2
  exit 1
fi

PLATFORM_URL="http://$LAN_IP:8000"
COLLECTION_URL="http://$LAN_IP:8200"
WEB_URL="http://$LAN_IP:$WEB_PORT"

start_screen "aipms-postgres" "bash scripts/run_postgres.sh"
start_screen \
  "aipms-collection" \
  "AIPMS_COLLECTION_BIND_HOST=0.0.0.0 AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1 bash scripts/run_collection_api.sh" \
  "$COLLECTION_URL/health"
start_screen \
  "aipms-platform" \
  "AIPMS_PLATFORM_BIND_HOST=0.0.0.0 AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1 bash scripts/run_platform_backend.sh" \
  "$PLATFORM_URL/health"
start_screen "aipms-worker" "bash scripts/run_analysis_worker_loop.sh"
start_screen \
  "aipms-web" \
  "cd web_client && VITE_API_BASE='$PLATFORM_URL' exec npm run dev -- --host 0.0.0.0 --port '$WEB_PORT'" \
  "$WEB_URL/"

wait_http "Platform API LAN" "$PLATFORM_URL/health"
wait_http "Collection API LAN" "$COLLECTION_URL/health"
wait_http "Web Client LAN" "$WEB_URL/"

cat > "$LOG_DIR/latest_urls.env" <<EOF
LAN_IP=$LAN_IP
WEB_URL=$WEB_URL
PLATFORM_URL=$PLATFORM_URL
COLLECTION_URL=$COLLECTION_URL
ANDROID_PLATFORM_BASE_URL=$PLATFORM_URL
ANDROID_COLLECTION_BASE_URL=$COLLECTION_URL
EOF

cat <<EOF
AI-PMS LAN execution stack is ready.

Web:
  $WEB_URL

Platform API:
  $PLATFORM_URL/health
  $PLATFORM_URL/docs

Collection API:
  $COLLECTION_URL/health
  $COLLECTION_URL/docs

Android LAN build:
  LAN_IP=$LAN_IP bash scripts/build_android_lan_debug.sh

Connectivity doctor:
  LAN_IP=$LAN_IP bash scripts/doctor_lan_connectivity.sh

Logs:
  $LOG_DIR

Restart:
  RESTART_LAN_STACK=1 bash scripts/run_lan_execution_stack.sh
EOF

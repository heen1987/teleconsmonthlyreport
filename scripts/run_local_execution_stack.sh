#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/runtime/local_execution"
RESTART_LOCAL_STACK="${RESTART_LOCAL_STACK:-0}"

mkdir -p "$LOG_DIR"

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

start_screen() {
  local name="$1"
  local command="$2"
  local log_file="$LOG_DIR/$name.log"

  if [ "$RESTART_LOCAL_STACK" = "1" ]; then
    stop_screen_sessions "$name"
  fi

  if screen_session_names "$name" | grep -q .; then
    return
  fi

  : > "$log_file"
  screen -dmS "$name" zsh -lc "cd '$ROOT_DIR' && exec $command > '$log_file' 2>&1"
}

wait_http() {
  local label="$1"
  local url="$2"
  local output="$LOG_DIR/${label// /_}.body"
  local status=""

  for _ in $(seq 1 60); do
    status="$(curl -sS -o "$output" -w '%{http_code}' "$url" || true)"
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

start_screen "aipms-postgres" "bash scripts/run_postgres.sh"
start_screen "aipms-collection" "bash scripts/run_collection_api.sh"
start_screen "aipms-analysis" "bash scripts/run_analysis_server.sh"
start_screen "aipms-worker" "bash scripts/run_analysis_worker_loop.sh"
start_screen "aipms-platform" "bash scripts/run_platform_backend.sh"
start_screen "aipms-web" "cd web_client && VITE_API_BASE='http://127.0.0.1:8000' exec npm run dev -- --host 0.0.0.0 --port 3000"

wait_http "Platform API" "http://127.0.0.1:8000/health"
wait_http "Collection API" "http://127.0.0.1:8200/health"
wait_http "Analysis Server" "http://127.0.0.1:8100/health"
wait_http "Web Client" "http://127.0.0.1:3000/"

cat <<EOF
AI-PMS local execution stack is ready.

Web:
  http://127.0.0.1:3000

Execution hub:
  http://127.0.0.1:3000/run/

Platform API:
  http://127.0.0.1:8000/docs

Collection API:
  http://127.0.0.1:8200/docs

Analysis Server:
  http://127.0.0.1:8100/docs

Logs:
  $LOG_DIR

Restart:
  RESTART_LOCAL_STACK=1 bash scripts/run_local_execution_stack.sh
EOF

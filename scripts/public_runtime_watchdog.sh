#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${AIPMS_RUNTIME_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_ROOT="${AIPMS_PUBLIC_RUNTIME_STATE_DIR:-$ROOT_DIR}"
LOG_DIR="${AIPMS_PUBLIC_RUNTIME_LOG_DIR:-$STATE_ROOT/logs}"
RUNTIME_DIR="${AIPMS_PUBLIC_RUNTIME_DIR:-$STATE_ROOT/runtime/always_on}"
TUNNEL_DIR="${AIPMS_PUBLIC_TUNNEL_DIR:-$STATE_ROOT/runtime/tunnels}"
SUMMARY_JSON="$RUNTIME_DIR/latest_public_runtime.json"
WEB_CACHE_DIR="${AIPMS_WEB_NODE_MODULES_CACHE:-$HOME/.cache/ai-pms/web_client}"
WEB_NODE_MODULES_DIR="$WEB_CACHE_DIR/node_modules"
WEB_PUBLIC_RUNTIME_DIR="${AIPMS_WEB_PUBLIC_RUNTIME_DIR:-/tmp/ai_pms_web_public_runtime}"

mkdir -p "$LOG_DIR" "$RUNTIME_DIR" "$TUNNEL_DIR"

http_status() {
  curl -L -sS --connect-timeout 5 --max-time 10 -o /tmp/aipms-watchdog.out -w '%{http_code}' "$1" 2>/dev/null || true
}

http_ok() {
  [ "$(http_status "$1")" = "200" ]
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
  local log_file="$LOG_DIR/$name.watchdog.log"

  stop_screen_sessions "$name"
  : > "$log_file"
  screen -dmS "$name" zsh -lc "$command > '$log_file' 2>&1"
}

ensure_api() {
  local name="$1"
  local url="$2"
  local command="$3"

  if http_ok "$url"; then
    return
  fi
  start_screen "$name" "$command"
}

prepare_web_runtime() {
  if [ ! -x "$WEB_NODE_MODULES_DIR/vite/bin/vite.js" ]; then
    mkdir -p "$WEB_CACHE_DIR"
    cp "$ROOT_DIR/web_client/package.json" "$WEB_CACHE_DIR/package.json"
    cp "$ROOT_DIR/web_client/package-lock.json" "$WEB_CACHE_DIR/package-lock.json"
    (cd "$WEB_CACHE_DIR" && npm ci --no-audit --no-fund)
  fi

  rm -rf "$WEB_PUBLIC_RUNTIME_DIR"
  mkdir -p "$WEB_PUBLIC_RUNTIME_DIR"
  cp "$ROOT_DIR/web_client/package.json" "$WEB_PUBLIC_RUNTIME_DIR/package.json"
  cp "$ROOT_DIR/web_client/package-lock.json" "$WEB_PUBLIC_RUNTIME_DIR/package-lock.json"
  cp "$ROOT_DIR/web_client/index.html" "$WEB_PUBLIC_RUNTIME_DIR/index.html"
  cp "$ROOT_DIR/web_client/vite.config.ts" "$WEB_PUBLIC_RUNTIME_DIR/vite.config.ts"
  cp -R "$ROOT_DIR/web_client/src" "$WEB_PUBLIC_RUNTIME_DIR/src"
  cp -R "$ROOT_DIR/web_client/public" "$WEB_PUBLIC_RUNTIME_DIR/public"
  ln -s "$WEB_NODE_MODULES_DIR" "$WEB_PUBLIC_RUNTIME_DIR/node_modules"
}

ensure_web() {
  if http_ok "http://127.0.0.1:3000/"; then
    return
  fi
  prepare_web_runtime
  start_screen "aipms-web" "cd '$WEB_PUBLIC_RUNTIME_DIR' && VITE_API_BASE='http://127.0.0.1:8000' exec node '$WEB_NODE_MODULES_DIR/vite/bin/vite.js' --host 127.0.0.1 --port 3000 --cors"
}

latest_tunnel_url() {
  local service="$1"
  local log_file
  for log_file in "$TUNNEL_DIR/$service.log" "$ROOT_DIR/runtime/tunnels/$service.log"; do
    [ -f "$log_file" ] || continue
    grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" 2>/dev/null | tail -1
  done | tail -1
}

ensure_tunnel() {
  local service="$1"
  local port="$2"
  local path="$3"
  local screen_name="aipms-tunnel-$service"
  local log_file="$TUNNEL_DIR/$service.log"
  local current_url

  current_url="$(latest_tunnel_url "$service" || true)"
  if [ -n "$current_url" ] && http_ok "$current_url$path"; then
    echo "$current_url"
    return
  fi

  stop_screen_sessions "$screen_name"
  : > "$log_file"
  screen -dmS "$screen_name" zsh -lc "exec cloudflared tunnel --url http://127.0.0.1:$port --no-autoupdate > '$log_file' 2>&1"

  for _ in $(seq 1 20); do
    current_url="$(latest_tunnel_url "$service" || true)"
    if [ -n "$current_url" ] && http_ok "$current_url$path"; then
      echo "$current_url"
      return
    fi
    sleep 2
  done

  echo "failed to start $service tunnel" >&2
  stop_screen_sessions "$screen_name"
  return 1
}

started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

ensure_api "aipms-platform" "http://127.0.0.1:8000/health" "cd '$ROOT_DIR/backend' && exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
ensure_api "aipms-collection" "http://127.0.0.1:8200/health" "cd '$ROOT_DIR/collection_api' && exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8200"
ensure_api "aipms-analysis" "http://127.0.0.1:8100/health" "cd '$ROOT_DIR/analysis_server' && exec .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8100"
ensure_web

platform_url="$(ensure_tunnel platform 8000 /health)"
collection_url="$(ensure_tunnel collection 8200 /health)"
analysis_url="$(ensure_tunnel analysis 8100 /health)"
web_url="$(ensure_tunnel web 3000 /)"

web_status="$(http_status "$web_url/")"
run_status="$(http_status "$web_url/run/")"
apk_status="$(http_status "$web_url/downloads/AI-PMS-Recorder.apk")"
platform_status="$(http_status "$platform_url/health")"
collection_status="$(http_status "$collection_url/health")"
analysis_status="$(http_status "$analysis_url/health")"

public_smoke_status="passed"
for status in "$web_status" "$run_status" "$apk_status" "$platform_status" "$collection_status" "$analysis_status"; do
  if [ "$status" != "200" ]; then
    public_smoke_status="failed"
  fi
done

export SUMMARY_JSON started_at public_smoke_status web_url platform_url collection_url analysis_url
export web_status run_status apk_status platform_status collection_status analysis_status
python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

summary = {
    "kind": "ai_pms_public_runtime_watchdog",
    "started_at": os.environ["started_at"],
    "finished_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "public_smoke_status": os.environ["public_smoke_status"],
    "public_urls": {
        "web_console": os.environ["web_url"],
        "run_hub": os.environ["web_url"] + "/run/",
        "apk_file": os.environ["web_url"] + "/downloads/AI-PMS-Recorder.apk",
        "platform_docs": os.environ["platform_url"] + "/docs",
        "collection_docs": os.environ["collection_url"] + "/docs",
        "analysis_docs": os.environ["analysis_url"] + "/docs",
    },
    "http_status": {
        "web": os.environ["web_status"],
        "run": os.environ["run_status"],
        "apk": os.environ["apk_status"],
        "platform": os.environ["platform_status"],
        "collection": os.environ["collection_status"],
        "analysis": os.environ["analysis_status"],
    },
}
Path(os.environ["SUMMARY_JSON"]).write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, ensure_ascii=False, indent=2))
PY

[ "$public_smoke_status" = "passed" ]

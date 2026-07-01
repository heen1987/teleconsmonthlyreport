#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
RESTART_PUBLIC_TUNNELS="${RESTART_PUBLIC_TUNNELS:-0}"
RESTART_WEB_FOR_PUBLIC="${RESTART_WEB_FOR_PUBLIC:-1}"
PUBLIC_TUNNEL_REUSE_HEALTH_CHECK="${AIPMS_PUBLIC_TUNNEL_REUSE_HEALTH_CHECK:-1}"
WEB_BIND_HOST="${AIPMS_WEB_BIND_HOST:-127.0.0.1}"
WEB_PORT="${AIPMS_WEB_PORT:-3000}"
WEB_ALLOW_PUBLIC_BIND="${AIPMS_WEB_ALLOW_PUBLIC_BIND:-0}"
WEB_CACHE_DIR="${AIPMS_WEB_NODE_MODULES_CACHE:-$HOME/.cache/ai-pms/web_client}"
WEB_NODE_MODULES_DIR="$WEB_CACHE_DIR/node_modules"
WEB_PUBLIC_RUNTIME_DIR="${AIPMS_WEB_PUBLIC_RUNTIME_DIR:-/tmp/ai_pms_web_public_runtime}"

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
  local health_path="${3:-/health}"
  local screen_name="aipms-tunnel-$service"
  local log_file="$TUNNEL_DIR/$service.log"

  if [ "$RESTART_PUBLIC_TUNNELS" = "1" ]; then
    stop_screen_sessions "$screen_name"
  fi

  if screen_session_names "$screen_name" | grep -q .; then
    if [ "$PUBLIC_TUNNEL_REUSE_HEALTH_CHECK" = "1" ]; then
      if public_tunnel_healthy "$service" "$health_path"; then
        return
      fi
      echo "Existing $service tunnel is stale. Restarting screen session." >&2
      stop_screen_sessions "$screen_name"
    else
      return
    fi
  fi

  : > "$log_file"
  screen -dmS "$screen_name" zsh -lc "cd '$ROOT_DIR' && exec cloudflared tunnel --url http://127.0.0.1:$port --no-autoupdate > '$log_file' 2>&1"
}

latest_tunnel_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  [ -f "$log_file" ] || return 1
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" 2>/dev/null | tail -1
}

public_tunnel_healthy() {
  local service="$1"
  local health_path="$2"
  local url
  local status

  url="$(latest_tunnel_url "$service" || true)"
  [ -n "$url" ] || return 1

  status="$(curl -L -sS --connect-timeout 5 --max-time 10 -o "/tmp/aipms-public-tunnel-$service.out" -w '%{http_code}' "$url$health_path" || true)"
  [ "$status" = "200" ]
}

wait_for_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  local url=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    url="$(latest_tunnel_url "$service" || true)"
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
    if curl -sS -o /tmp/aipms-public-web-local.html -w '%{http_code}' "http://127.0.0.1:$WEB_PORT/" | grep -q '^200$'; then
      return 0
    fi
    sleep 2
  done
  echo "Web client did not become healthy on 127.0.0.1:$WEB_PORT." >&2
  return 1
}

prepare_public_web_runtime() {
  if [ ! -x "$WEB_NODE_MODULES_DIR/vite/bin/vite.js" ]; then
    bash "$ROOT_DIR/scripts/repair_web_dependencies.sh"
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

require_command cloudflared
require_command screen

case "$WEB_BIND_HOST" in
  "0.0.0.0"|"::")
    if [ "$WEB_ALLOW_PUBLIC_BIND" != "1" ]; then
      cat >&2 <<'EOF'
Refusing to bind Web dev server to a public interface.

Default external-network policy:
  - keep Web dev server on 127.0.0.1
  - expose it through the Cloudflare tunnel created by this script

If you intentionally need direct LAN binding, rerun with:
  AIPMS_WEB_BIND_HOST=0.0.0.0 AIPMS_WEB_ALLOW_PUBLIC_BIND=1 bash scripts/run_public_tunnels.sh
EOF
      exit 1
    fi
    ;;
esac

ensure_local_service "Platform API" 8000
ensure_local_service "Collection API" 8200
ensure_local_service "Analysis server" 8100

start_tunnel platform 8000 /health
start_tunnel collection 8200 /health
start_tunnel analysis 8100 /health

platform_url="$(wait_for_url platform)"
collection_url="$(wait_for_url collection)"
analysis_url="$(wait_for_url analysis)"

if [ "$RESTART_WEB_FOR_PUBLIC" = "1" ]; then
  stop_screen_sessions "aipms-web"
  prepare_public_web_runtime
  screen -dmS aipms-web zsh -lc "cd '$WEB_PUBLIC_RUNTIME_DIR' && VITE_API_BASE='$platform_url' exec node '$WEB_NODE_MODULES_DIR/vite/bin/vite.js' --host '$WEB_BIND_HOST' --port '$WEB_PORT' --cors"
  wait_for_web
fi

start_tunnel web "$WEB_PORT" /
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

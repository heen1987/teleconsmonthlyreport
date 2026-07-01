#!/usr/bin/env bash
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DEPLOY_ROOT="/Users/ppp/Documents/새싹_프로젝트1/ai_pms_bootstrap"
DEPLOY_ROOT="${AIPMS_DEPLOY_ROOT:-$DEFAULT_DEPLOY_ROOT}"
MODE="${1:---deploy}"
LOG_DIR="$DEPLOY_ROOT/runtime/self_hosted_deploy"
WEB_API_BASE="${VITE_API_BASE:-${AIPMS_WEB_API_BASE:-http://127.0.0.1:8000}}"
DEPLOY_PROFILE="${AIPMS_DEPLOY_PROFILE:-full}"
PLATFORM_API_URL="${AIPMS_PLATFORM_API_URL:-}"

usage() {
  cat <<EOF
Usage: bash scripts/deploy_mac_mini_from_runner.sh [--check|--sync-only|--deploy]

Environment:
  AIPMS_DEPLOY_ROOT   Target runtime root. Default: $DEFAULT_DEPLOY_ROOT
  AIPMS_WEB_API_BASE  Web VITE_API_BASE for local runtime. Default: http://127.0.0.1:8000
  AIPMS_DEPLOY_PROFILE
                     full or collection-analysis. Default: full
  AIPMS_PLATFORM_API_URL
                     Required for collection-analysis. Platform server URL
                     written to collection_api/.env. Do not use a LAN IP.
EOF
}

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

  stop_screen_sessions "$name"
  : > "$log_file"
  screen -dmS "$name" zsh -lc "cd '$DEPLOY_ROOT' && $command > '$log_file' 2>&1"
}

wait_http() {
  local label="$1"
  local url="$2"
  local body="$LOG_DIR/${label// /_}.body"
  local status

  for _ in $(seq 1 60); do
    status="$(curl -L -sS --connect-timeout 3 --max-time 8 -o "$body" -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [ "$status" = "200" ]; then
      echo "$label ready: $url"
      return 0
    fi
    sleep 2
  done

  echo "$label did not become ready: $url" >&2
  cat "$body" >&2 || true
  return 1
}

sync_path() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  rsync -a --delete \
    --exclude '.env' \
    --exclude '.venv' \
    --exclude '.venv-win' \
    --exclude '__pycache__' \
    --exclude 'node_modules' \
    --exclude 'dist' \
    --exclude 'logs' \
    --exclude 'runtime' \
    --exclude 'storage' \
    "$source" "$target"
}

sync_project() {
  mkdir -p "$DEPLOY_ROOT"

  local dirs
  case "$DEPLOY_PROFILE" in
    full)
      dirs="backend collection_api analysis_server android_client web_client contracts scripts docs models"
      ;;
    collection-analysis)
      dirs="collection_api contracts scripts docs models"
      ;;
    *)
      echo "Unsupported AIPMS_DEPLOY_PROFILE: $DEPLOY_PROFILE" >&2
      exit 2
      ;;
  esac

  for dir in $dirs; do
    if [ -d "$SRC_ROOT/$dir" ]; then
      sync_path "$SRC_ROOT/$dir/" "$DEPLOY_ROOT/$dir/"
    fi
  done

  for file in README.md docker-compose.yml .gitignore AGENTS.md CLAUDE.md RAG_AGENT_ERP_ROADMAP.md; do
    if [ -f "$SRC_ROOT/$file" ]; then
      cp "$SRC_ROOT/$file" "$DEPLOY_ROOT/$file"
    fi
  done

  chmod +x "$DEPLOY_ROOT"/scripts/*.sh 2>/dev/null || true
}

set_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  mkdir -p "$(dirname "$env_file")"
  touch "$env_file"
  tmp_file="$(mktemp)"
  if grep -q "^${key}=" "$env_file"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ "^" key "=" {
        print key "=" value
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) print key "=" value
      }
    ' "$env_file" > "$tmp_file"
  else
    cat "$env_file" > "$tmp_file"
    printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
  fi
  mv "$tmp_file" "$env_file"
}

require_platform_server_url() {
  if [ -z "$PLATFORM_API_URL" ]; then
    cat >&2 <<'EOF'
AIPMS_PLATFORM_API_URL is required for collection-analysis deploy.

Set it to the Platform server public URL, for example:
  AIPMS_PLATFORM_API_URL=https://<platform-server-url>

Do not point Collection/Analysis at this PC or a Mac mini LAN IP.
EOF
    exit 2
  fi

  case "$PLATFORM_API_URL" in
    http://127.*|https://127.*|http://localhost*|https://localhost*|\
    http://10.*|https://10.*|http://192.168.*|https://192.168.*|\
    http://172.1[6-9].*|https://172.1[6-9].*|http://172.2[0-9].*|https://172.2[0-9].*|\
    http://172.3[0-1].*|https://172.3[0-1].*)
      cat >&2 <<EOF
AIPMS_PLATFORM_API_URL must be the Platform server URL, not a local/LAN IP:
  current: $PLATFORM_API_URL
EOF
      exit 2
      ;;
  esac
}

configure_collection_env() {
  local env_file="$DEPLOY_ROOT/collection_api/.env"
  if [ ! -f "$env_file" ]; then
    cp "$DEPLOY_ROOT/collection_api/.env.example" "$env_file"
  fi

  require_platform_server_url
  set_env_value "$env_file" "PLATFORM_API_URL" "$PLATFORM_API_URL"
  echo "collection_api/.env PLATFORM_API_URL updated from Platform server URL"
  set_env_value "$env_file" "WORKER_LOOP_ENABLED" "true"
}

ensure_python_deps() {
  local service_dir="$1"
  local py_bin="$DEPLOY_ROOT/$service_dir/.venv/bin/python"

  if [ ! -x "$py_bin" ]; then
    python3 -m venv "$DEPLOY_ROOT/$service_dir/.venv"
  fi
  "$py_bin" -m pip install -r "$DEPLOY_ROOT/$service_dir/requirements.txt"
}

deploy_full() {
  mkdir -p "$LOG_DIR"

  ensure_python_deps backend
  ensure_python_deps collection_api
  ensure_python_deps analysis_server
  bash "$DEPLOY_ROOT/scripts/repair_web_dependencies.sh"

  bash "$DEPLOY_ROOT/scripts/apply_platform_schema.sh"
  bash "$DEPLOY_ROOT/scripts/apply_collection_schema.sh"

  start_screen "aipms-collection" "bash scripts/run_collection_api.sh"
  start_screen "aipms-analysis" "bash scripts/run_analysis_server.sh"
  start_screen "aipms-platform" "bash scripts/run_platform_backend.sh"
  start_screen "aipms-web" "cd web_client && VITE_API_BASE='$WEB_API_BASE' exec npm run dev -- --host 127.0.0.1 --port 3000"

  wait_http "Platform API" "http://127.0.0.1:8000/health"
  wait_http "Collection API" "http://127.0.0.1:8200/health"
  wait_http "Analysis Server" "http://127.0.0.1:8100/health"
  wait_http "Web Client" "http://127.0.0.1:3000/"

  bash "$DEPLOY_ROOT/scripts/install_launchd_public_runtime.sh" --load || true
  bash "$DEPLOY_ROOT/scripts/doctor_cross_server_connectivity.sh"
}

deploy_collection_analysis() {
  mkdir -p "$LOG_DIR"

  configure_collection_env
  ensure_python_deps collection_api

  bash "$DEPLOY_ROOT/scripts/apply_collection_schema.sh"

  start_screen "aipms-collection" "bash scripts/run_collection_api.sh"
  wait_http "Collection API" "http://127.0.0.1:8200/health"

  cat <<EOF
Collection/Analysis deploy complete.

Runtime:
  - Collection API: http://127.0.0.1:8200
  - Integrated analysis worker: collection_api startup task

Next:
  - expose Collection API through Cloudflare tunnel or a private network
  - set Android aipmsPlatformBaseUrl to the Platform server URL
  - set Android aipmsCollectionBaseUrl to the Collection public URL
EOF
}

case "$MODE" in
  --check)
    if [ "$DEPLOY_PROFILE" = "collection-analysis" ]; then
      require_platform_server_url
    elif [ "$DEPLOY_PROFILE" != "full" ]; then
      echo "Unsupported AIPMS_DEPLOY_PROFILE: $DEPLOY_PROFILE" >&2
      exit 2
    fi
    require_command rsync
    require_command screen
    require_command curl
    require_command python3
    [ -d "$SRC_ROOT/collection_api" ]
    if [ "$DEPLOY_PROFILE" = "full" ]; then
      [ -d "$SRC_ROOT/backend" ]
      [ -d "$SRC_ROOT/analysis_server" ]
      [ -d "$SRC_ROOT/web_client" ]
    fi
    echo "self-hosted deploy check passed ($DEPLOY_PROFILE)"
    ;;
  --sync-only)
    require_command rsync
    sync_project
    echo "Synced source to: $DEPLOY_ROOT"
    ;;
  --deploy)
    require_command rsync
    require_command screen
    require_command curl
    require_command python3
    sync_project
    case "$DEPLOY_PROFILE" in
      full)
        deploy_full
        ;;
      collection-analysis)
        deploy_collection_analysis
        ;;
      *)
        echo "Unsupported AIPMS_DEPLOY_PROFILE: $DEPLOY_PROFILE" >&2
        exit 2
        ;;
    esac
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
CONNECT_TIMEOUT="${AIPMS_PUBLIC_SMOKE_CONNECT_TIMEOUT:-8}"
MAX_TIME="${AIPMS_PUBLIC_SMOKE_MAX_TIME:-30}"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/smoke_public_access.sh [WEB_URL] [PLATFORM_URL] [COLLECTION_URL] [ANALYSIS_URL]

URL resolution order:
  1. positional argument
  2. AIPMS_PUBLIC_*_URL environment variable
  3. latest runtime/tunnels/<service>.log quick-tunnel URL

Examples:
  bash scripts/smoke_public_access.sh
  bash scripts/smoke_public_access.sh https://web.example.com https://api.example.com https://collection.example.com https://analysis.example.com
  AIPMS_PUBLIC_WEB_URL=https://web.example.com bash scripts/smoke_public_access.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

fail() {
  echo "$1" >&2
  cat >&2 <<'EOF'

Public tunnel recovery:
  RESTART_PUBLIC_TUNNELS=1 AIPMS_REFRESH_START_TUNNELS=1 bash scripts/refresh_public_handoff_bundle.sh

Named/fixed tunnel path:
  bash scripts/prepare_cloudflare_named_tunnel.sh
  bash scripts/run_cloudflare_named_tunnel.sh
EOF
  exit 1
}

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    echo "Missing tunnel log: $log_file" >&2
    return 1
  fi
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

resolve_url() {
  local service="$1"
  local positional="$2"
  local env_value="$3"
  local url="$positional"
  if [ -z "$url" ]; then
    url="$env_value"
  fi
  if [ -z "$url" ]; then
    url="$(extract_url "$service" || true)"
  fi
  url="${url%/}"
  if [ -z "$url" ]; then
    fail "Missing public URL for $service."
  fi
  printf "%s" "$url"
}

WEB_URL="$(resolve_url web "${1:-}" "${AIPMS_PUBLIC_WEB_URL:-}")"
PLATFORM_URL="$(resolve_url platform "${2:-}" "${AIPMS_PUBLIC_PLATFORM_URL:-}")"
COLLECTION_URL="$(resolve_url collection "${3:-}" "${AIPMS_PUBLIC_COLLECTION_URL:-}")"
ANALYSIS_URL="$(resolve_url analysis "${4:-}" "${AIPMS_PUBLIC_ANALYSIS_URL:-}")"
APK_FILE_NAME="AiPmsAndroidClient-responsive-public-debug.apk"
APK_ALIAS_NAME="AI-PMS-Recorder.apk"
REQUIREMENTS_DOCX_NAME="AI-PMS-requirements-v0.2.docx"
REQUIREMENTS_MD_NAME="AI-PMS-requirements-v0.2.md"

check_get() {
  local label="$1"
  local url="$2"
  local output="$3"
  local status
  : > "$output"
  status="$(curl -L -sS --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o "$output" -w '%{http_code}' "$url" || true)"
  if [ "$status" != "200" ]; then
    echo "$label failed: HTTP ${status:-000} ($url)" >&2
    cat "$output" >&2 || true
    fail "Public access smoke failed at: $label"
  fi
}

check_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if ! grep -q "$pattern" "$file"; then
    echo "$label missing expected marker: $pattern" >&2
    cat "$file" >&2 || true
    exit 1
  fi
}

check_min_size() {
  local label="$1"
  local url="$2"
  local min_bytes="$3"
  local output="$4"
  local result status size
  : > "$output"
  result="$(curl -L -sS --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o "$output" -w '%{http_code} %{size_download}' "$url" || true)"
  status="${result%% *}"
  size="${result##* }"
  if [ "$status" != "200" ] || [ "$size" -lt "$min_bytes" ]; then
    echo "$label failed: HTTP ${status:-000}, size ${size:-0} ($url)" >&2
    fail "Public access smoke failed at: $label"
  fi
}

check_get "Web public access" "$WEB_URL/" /tmp/aipms-public-web.html
check_get "Web execution hub route" "$WEB_URL/run/" /tmp/aipms-public-run.html
check_get "Web execution hub static" "$WEB_URL/run/index.html" /tmp/aipms-public-run-index.html
check_get "Web execution JSON" "$WEB_URL/run/execution.json" /tmp/aipms-public-run.json
check_get "Platform public health" "$PLATFORM_URL/health" /tmp/aipms-public-platform.json
check_get "Collection public health" "$COLLECTION_URL/health" /tmp/aipms-public-collection.json
check_get "Analysis public health" "$ANALYSIS_URL/health" /tmp/aipms-public-analysis.json
check_get "Web APK download route" "$WEB_URL/downloads/" /tmp/aipms-public-downloads.html
check_get "Web APK install guide" "$WEB_URL/downloads/install.html" /tmp/aipms-public-install-guide.html
check_get "Web handoff route" "$WEB_URL/handoff/" /tmp/aipms-public-handoff-route.html
check_get "Web handoff static" "$WEB_URL/handoff/index.html" /tmp/aipms-public-handoff.html
check_get "Web review package" "$WEB_URL/handoff/public-review-package.json" /tmp/aipms-public-review-package.json
check_get "Web review response template" "$WEB_URL/handoff/review-response-template.md" /tmp/aipms-public-review-response-template.md
check_get "Web APK metadata" "$WEB_URL/downloads/android-apk.json" /tmp/aipms-public-apk.json
check_get "Web requirements manifest" "$WEB_URL/requirements/requirements.json" /tmp/aipms-public-requirements.json
check_get "Web requirements Markdown" "$WEB_URL/requirements/$REQUIREMENTS_MD_NAME" /tmp/aipms-public-requirements.md
check_contains "Install guide" /tmp/aipms-public-install-guide.html "AI-PMS Recorder 설치 확인"
check_contains "Install guide" /tmp/aipms-public-install-guide.html "휴대폰 / 태블릿"
check_contains "Execution hub" /tmp/aipms-public-run-index.html "MEETFLOW"
check_contains "Execution hub" /tmp/aipms-public-run-index.html "전체 처리 흐름"
check_contains "Execution JSON" /tmp/aipms-public-run.json "public_execution_hub"
check_contains "Execution JSON" /tmp/aipms-public-run.json "android_apk"
check_contains "Execution JSON" /tmp/aipms-public-run.json "requirements_docx"
check_contains "Review package" /tmp/aipms-public-review-package.json "public_review_package"
check_contains "Review package" /tmp/aipms-public-review-package.json "review_scopes"
check_contains "Review package" /tmp/aipms-public-review-package.json "apk_install_guide"
check_contains "Review package" /tmp/aipms-public-review-package.json "requirements"
check_contains "Review package" /tmp/aipms-public-review-package.json "requirements_docx"
check_contains "Review package" /tmp/aipms-public-review-package.json "review_response_template"
check_contains "Review package" /tmp/aipms-public-review-package.json "response_collection"
check_contains "Review response template" /tmp/aipms-public-review-response-template.md "AI-PMS 파트별 검토 회신 템플릿"
check_contains "Review response template" /tmp/aipms-public-review-response-template.md "요구사항정의서"
check_contains "Handoff page" /tmp/aipms-public-handoff.html "AI-PMS 화면 확인"
check_contains "Handoff page" /tmp/aipms-public-handoff.html "전체 처리 흐름"
check_contains "Review response template" /tmp/aipms-public-review-response-template.md "승인 가능 / 수정 필요 / 질문 / 미검증"
check_contains "APK metadata" /tmp/aipms-public-apk.json "$APK_FILE_NAME"
check_contains "APK metadata" /tmp/aipms-public-apk.json "$APK_ALIAS_NAME"
check_contains "APK metadata" /tmp/aipms-public-apk.json "responsive_phone_tablet"
check_contains "Requirements manifest" /tmp/aipms-public-requirements.json "requirements_documents"
check_contains "Requirements manifest" /tmp/aipms-public-requirements.json "$REQUIREMENTS_DOCX_NAME"
check_contains "Requirements Markdown" /tmp/aipms-public-requirements.md "AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서"
check_contains "Requirements Markdown" /tmp/aipms-public-requirements.md "MVP 범위 통제 기준"
check_min_size "Web APK file" "$WEB_URL/downloads/$APK_FILE_NAME" 1000000 /tmp/aipms-public-apk.apk
check_min_size "Web APK alias file" "$WEB_URL/downloads/$APK_ALIAS_NAME" 1000000 /tmp/aipms-public-apk-alias.apk
check_min_size "Web requirements DOCX" "$WEB_URL/requirements/$REQUIREMENTS_DOCX_NAME" 20000 /tmp/aipms-public-requirements.docx

source_status="$(curl -L -sS --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o /tmp/aipms-public-main.tsx -w '%{http_code}' "$WEB_URL/src/main.tsx" || true)"
if [ "$source_status" = "200" ]; then
  check_contains "Web source public run route" /tmp/aipms-public-main.tsx "PublicRunPage"
  check_contains "Web source manifest hook" /tmp/aipms-public-main.tsx "usePublicExecutionManifest"
  check_contains "Web source public download route" /tmp/aipms-public-main.tsx "PublicDownloadPage"
  check_contains "Web source public handoff route" /tmp/aipms-public-main.tsx "PublicHandoffPage"
fi

cors_status="$(
  curl -sS --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o /tmp/aipms-public-cors-body.txt -w '%{http_code}' \
    -X OPTIONS "$PLATFORM_URL/users/me" \
    -H "Origin: $WEB_URL" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Authorization,Content-Type" \
    || true
)"
if [ "$cors_status" != "200" ]; then
  echo "Platform public CORS preflight failed: HTTP $cors_status" >&2
  cat /tmp/aipms-public-cors-body.txt >&2 || true
  fail "Public access smoke failed at: Platform public CORS preflight"
fi

echo "{'web': '200', 'run': '200', 'run_static': '200', 'run_json': '200', 'downloads': '200', 'install_guide': '200', 'handoff': '200', 'handoff_static': '200', 'review_package': '200', 'response_template': '200', 'requirements_manifest': '200', 'requirements_markdown': '200', 'requirements_docx': '200', 'apk': '200', 'apk_alias': '200', 'platform': '200', 'collection': '200', 'analysis': '200', 'cors': '$cors_status'}"

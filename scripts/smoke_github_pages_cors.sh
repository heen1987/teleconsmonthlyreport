#!/usr/bin/env bash
set -euo pipefail

PLATFORM_URL="${AIPMS_PLATFORM_PUBLIC_URL:-${1:-http://127.0.0.1:8000}}"
ORIGIN="${AIPMS_GITHUB_PAGES_ORIGIN:-https://juyeoon.github.io}"
CONNECT_TIMEOUT="${AIPMS_CORS_SMOKE_CONNECT_TIMEOUT:-8}"
MAX_TIME="${AIPMS_CORS_SMOKE_MAX_TIME:-20}"
HEADERS_FILE="/tmp/aipms-github-pages-cors-headers.txt"
BODY_FILE="/tmp/aipms-github-pages-cors-body.txt"

status="$(
  curl -sS --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -D "$HEADERS_FILE" -o "$BODY_FILE" -w "%{http_code}" \
    -X OPTIONS "$PLATFORM_URL/users/me" \
    -H "Origin: $ORIGIN" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Authorization,Content-Type" \
    || true
)"

if [ "$status" != "200" ]; then
  echo "GitHub Pages CORS preflight failed: HTTP ${status:-000}" >&2
  cat "$BODY_FILE" >&2 || true
  exit 1
fi

if ! grep -qi "^access-control-allow-origin: $ORIGIN" "$HEADERS_FILE"; then
  echo "GitHub Pages CORS allow-origin header mismatch" >&2
  cat "$HEADERS_FILE" >&2 || true
  exit 1
fi

echo "{'platform': '$PLATFORM_URL', 'github_pages_origin': '$ORIGIN', 'cors': 'ok'}"

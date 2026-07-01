#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/web_client"
CACHE_DIR="${AIPMS_WEB_NODE_MODULES_CACHE:-$HOME/.cache/ai-pms/web_client}"
NODE_MODULES_DIR="$CACHE_DIR/node_modules"
TEMP_BUILD_DIR="${AIPMS_WEB_TEMP_BUILD_DIR:-$(mktemp -d /tmp/ai_pms_web_build.XXXXXX)}"
KEEP_TEMP="${AIPMS_WEB_KEEP_TEMP_BUILD:-0}"

cleanup() {
  if [ "$KEEP_TEMP" != "1" ] && [[ "$TEMP_BUILD_DIR" == /tmp/ai_pms_web_build.* ]]; then
    rm -rf "$TEMP_BUILD_DIR"
  fi
}
trap cleanup EXIT

if [ ! -x "$NODE_MODULES_DIR/vite/bin/vite.js" ]; then
  bash "$ROOT_DIR/scripts/repair_web_dependencies.sh"
fi

rm -rf "$TEMP_BUILD_DIR"
mkdir -p "$TEMP_BUILD_DIR"

cp "$WEB_DIR/package.json" "$TEMP_BUILD_DIR/package.json"
cp "$WEB_DIR/package-lock.json" "$TEMP_BUILD_DIR/package-lock.json"
cp "$WEB_DIR/index.html" "$TEMP_BUILD_DIR/index.html"
cp "$WEB_DIR/vite.config.ts" "$TEMP_BUILD_DIR/vite.config.ts"
cp -R "$WEB_DIR/src" "$TEMP_BUILD_DIR/src"
cp -R "$WEB_DIR/public" "$TEMP_BUILD_DIR/public"
ln -s "$NODE_MODULES_DIR" "$TEMP_BUILD_DIR/node_modules"

(
  cd "$TEMP_BUILD_DIR"
  VITE_API_BASE="${VITE_API_BASE:-http://127.0.0.1:8000}" \
    node "$NODE_MODULES_DIR/vite/bin/vite.js" build
)

echo "Web static build passed: $TEMP_BUILD_DIR/dist"

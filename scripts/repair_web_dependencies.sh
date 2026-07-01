#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/web_client"
CACHE_DIR="${AIPMS_WEB_NODE_MODULES_CACHE:-$HOME/.cache/ai-pms/web_client}"
NODE_MODULES_TARGET="$CACHE_DIR/node_modules"

if [ ! -f "$WEB_DIR/package.json" ]; then
  echo "missing web_client/package.json" >&2
  exit 1
fi

if [ ! -f "$WEB_DIR/package-lock.json" ]; then
  echo "missing web_client/package-lock.json" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"
cp "$WEB_DIR/package.json" "$CACHE_DIR/package.json"
cp "$WEB_DIR/package-lock.json" "$CACHE_DIR/package-lock.json"

echo "Installing Web dependencies outside Google Drive:"
echo "$CACHE_DIR"
(
  cd "$CACHE_DIR"
  npm ci --no-audit --no-fund
)

if [ ! -x "$NODE_MODULES_TARGET/.bin/vite" ]; then
  echo "Vite binary was not installed correctly: $NODE_MODULES_TARGET/.bin/vite" >&2
  exit 1
fi

if [ ! -s "$NODE_MODULES_TARGET/vite/bin/vite.js" ]; then
  echo "Vite package is empty or missing: $NODE_MODULES_TARGET/vite/bin/vite.js" >&2
  exit 1
fi

if [ -L "$WEB_DIR/node_modules" ]; then
  current_target="$(readlink "$WEB_DIR/node_modules")"
  if [ "$current_target" = "$NODE_MODULES_TARGET" ]; then
    echo "web_client/node_modules already points to cache target."
  else
    rm "$WEB_DIR/node_modules"
    ln -s "$NODE_MODULES_TARGET" "$WEB_DIR/node_modules"
  fi
elif [ -e "$WEB_DIR/node_modules" ]; then
  stamp="$(date +%Y%m%d%H%M%S)"
  mv "$WEB_DIR/node_modules" "$WEB_DIR/.node_modules_broken_$stamp"
  ln -s "$NODE_MODULES_TARGET" "$WEB_DIR/node_modules"
else
  ln -s "$NODE_MODULES_TARGET" "$WEB_DIR/node_modules"
fi

echo "Web dependencies ready:"
echo "$WEB_DIR/node_modules -> $NODE_MODULES_TARGET"

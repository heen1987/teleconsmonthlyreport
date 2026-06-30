#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${AIPMS_CF_OUT_DIR:-$ROOT_DIR/runtime/cloudflare_named_tunnel}"
EXAMPLE_CONFIG="$OUT_DIR/config.example.yml"
CONFIG_FILE="$OUT_DIR/config.yml"
TUNNEL_NAME="${AIPMS_CF_TUNNEL_NAME:-ai-pms}"

mkdir -p "$OUT_DIR"

write_config() {
  local target="$1"
  local tunnel_id="$2"
  local credentials_file="$3"
  local web_hostname="$4"
  local platform_hostname="$5"
  local collection_hostname="$6"
  local analysis_hostname="$7"

  cat > "$target" <<EOF
tunnel: $tunnel_id
credentials-file: $credentials_file

ingress:
  - hostname: $web_hostname
    service: http://127.0.0.1:3000
  - hostname: $platform_hostname
    service: http://127.0.0.1:8000
  - hostname: $collection_hostname
    service: http://127.0.0.1:8200
  - hostname: $analysis_hostname
    service: http://127.0.0.1:8100
  - service: http_status:404
EOF
}

write_config \
  "$EXAMPLE_CONFIG" \
  "<cloudflare-tunnel-id>" \
  "$HOME/.cloudflared/<cloudflare-tunnel-id>.json" \
  "pms.example.com" \
  "api.pms.example.com" \
  "collection.pms.example.com" \
  "analysis.pms.example.com"

missing=0
for name in \
  AIPMS_CF_TUNNEL_ID \
  AIPMS_CF_WEB_HOSTNAME \
  AIPMS_CF_PLATFORM_HOSTNAME \
  AIPMS_CF_COLLECTION_HOSTNAME \
  AIPMS_CF_ANALYSIS_HOSTNAME
do
  if [ -z "${!name:-}" ]; then
    echo "Missing optional named-tunnel env: $name"
    missing=1
  fi
done

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Missing required command for actual named tunnel run: cloudflared"
  missing=1
fi

if [ "$missing" = "0" ]; then
  credentials_file="${AIPMS_CF_CREDENTIALS_FILE:-$HOME/.cloudflared/$AIPMS_CF_TUNNEL_ID.json}"
  write_config \
    "$CONFIG_FILE" \
    "$AIPMS_CF_TUNNEL_ID" \
    "$credentials_file" \
    "$AIPMS_CF_WEB_HOSTNAME" \
    "$AIPMS_CF_PLATFORM_HOSTNAME" \
    "$AIPMS_CF_COLLECTION_HOSTNAME" \
    "$AIPMS_CF_ANALYSIS_HOSTNAME"
  echo "Cloudflare named tunnel config written: $CONFIG_FILE"
  echo "Run: bash scripts/run_cloudflare_named_tunnel.sh"
else
  echo "Cloudflare named tunnel example written: $EXAMPLE_CONFIG"
  echo "To create the tunnel manually:"
  echo "  cloudflared tunnel login"
  echo "  cloudflared tunnel create $TUNNEL_NAME"
  echo "  cloudflared tunnel route dns $TUNNEL_NAME <hostname>"
  echo "Then export the AIPMS_CF_* variables and rerun this script."
  if [ "${AIPMS_CF_STRICT:-0}" = "1" ]; then
    exit 1
  fi
fi

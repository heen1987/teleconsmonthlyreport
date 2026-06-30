#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LAN_IP="${LAN_IP:-}"
if [ -z "$LAN_IP" ]; then
  for iface in en1 en0; do
    if ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"; then
      if [ -n "$ip" ]; then
        LAN_IP="$ip"
        break
      fi
    fi
  done
fi
if [ -z "$LAN_IP" ]; then
  LAN_IP="$(ifconfig | awk '/inet / && $2 !~ /^127\./ { print $2; exit }')"
fi
if [ -z "$LAN_IP" ]; then
  echo "LAN IP not found. Set LAN_IP manually." >&2
  exit 1
fi

platform_status="$(curl -s -o /tmp/aipms-lan-platform.json -w '%{http_code}' "http://$LAN_IP:8000/health")"
if [ "$platform_status" != "200" ]; then
  echo "Platform API LAN health failed: HTTP $platform_status" >&2
  cat /tmp/aipms-lan-platform.json >&2 || true
  exit 1
fi

web_status="$(curl -s -o /tmp/aipms-lan-web.html -w '%{http_code}' "http://$LAN_IP:3000/")"
if [ "$web_status" != "200" ]; then
  echo "Web LAN access failed: HTTP $web_status" >&2
  cat /tmp/aipms-lan-web.html >&2 || true
  exit 1
fi

cors_status="$(
  curl -s -o /tmp/aipms-lan-cors-body.txt -w '%{http_code}' \
    -X OPTIONS "http://$LAN_IP:8000/users/me" \
    -H "Origin: http://$LAN_IP:3000" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Authorization,Content-Type"
)"
if [ "$cors_status" != "200" ]; then
  echo "Platform API CORS preflight failed: HTTP $cors_status" >&2
  cat /tmp/aipms-lan-cors-body.txt >&2 || true
  exit 1
fi

echo "{'lan_ip': '$LAN_IP', 'web': '$web_status', 'platform': '$platform_status', 'cors': '$cors_status'}"

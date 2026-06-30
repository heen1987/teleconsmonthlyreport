#!/usr/bin/env bash
set -euo pipefail

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
  LAN_IP="$(ifconfig | awk '/inet / && $2 !~ /^127\\./ { print $2; exit }')"
fi

if [ -z "$LAN_IP" ]; then
  echo "LAN IP not found. Check Wi-Fi/Ethernet connection." >&2
  exit 1
fi

cat <<EOF
AI-PMS LAN access URLs

Web client:
  http://$LAN_IP:3000

Platform API:
  http://$LAN_IP:8000/health
  http://$LAN_IP:8000/docs

Collection API, if running:
  http://$LAN_IP:8200/health
  http://$LAN_IP:8200/docs

Analysis server, if running:
  http://$LAN_IP:8100/health
  http://$LAN_IP:8100/docs
EOF

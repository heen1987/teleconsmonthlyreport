#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/runtime/cloudflare_dns_origin"
JSON_OUT="$OUT_DIR/latest_report.json"
MD_OUT="$OUT_DIR/latest_report.md"
TMP_BODY="${TMPDIR:-/tmp}/aipms-cloudflare-origin-body.$$"

mkdir -p "$OUT_DIR"

cleanup() {
  rm -f "$TMP_BODY"
}
trap cleanup EXIT

http_status() {
  local url="$1"
  curl -L -sS --connect-timeout 5 --max-time 10 -o "$TMP_BODY" -w '%{http_code}' "$url" 2>/dev/null || true
}

tcp_status() {
  local host="$1"
  local port="$2"
  if nc -z -G 3 "$host" "$port" >/dev/null 2>&1; then
    echo "open"
  else
    echo "closed"
  fi
}

resolve_host() {
  local host="$1"
  python3 - "$host" <<'PY'
from __future__ import annotations

import socket
import sys

host = sys.argv[1]
try:
    infos = socket.getaddrinfo(host, None, proto=socket.IPPROTO_TCP)
except Exception:
    raise SystemExit(0)
values = sorted({item[4][0] for item in infos})
print(",".join(values))
PY
}

public_ip="$(curl -sS --connect-timeout 5 --max-time 10 https://ifconfig.me 2>/dev/null || true)"
lan_ip_en0="$(ipconfig getifaddr en0 2>/dev/null || true)"
lan_ip_en1="$(ipconfig getifaddr en1 2>/dev/null || true)"
lan_ip="${AIPMS_ORIGIN_LAN_IP:-${lan_ip_en0:-$lan_ip_en1}}"

WEB_HOST="${AIPMS_CF_WEB_HOSTNAME:-${AIPMS_DOMAIN_WEB:-}}"
PLATFORM_HOST="${AIPMS_CF_PLATFORM_HOSTNAME:-${AIPMS_DOMAIN_PLATFORM:-}}"
COLLECTION_HOST="${AIPMS_CF_COLLECTION_HOSTNAME:-${AIPMS_DOMAIN_COLLECTION:-}}"
ROOT_HOST="${AIPMS_DOMAIN_ROOT:-}"
EXPECT_ORIGIN_PROXY="${AIPMS_EXPECT_ORIGIN_PROXY:-0}"
EXPECT_DOMAIN_LIVE="${AIPMS_EXPECT_DOMAIN_LIVE:-0}"

CHECKS_FILE="$OUT_DIR/latest_checks.tsv"
: > "$CHECKS_FILE"

record_check() {
  local label="$1"
  local target="$2"
  local required="$3"
  local status="$4"
  local note="$5"
  printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$target" "$required" "$status" "$note" >> "$CHECKS_FILE"
}

record_check "public_ip" "https://ifconfig.me" "true" "${public_ip:-missing}" "Cloudflare A record origin IP"
record_check "lan_ip" "en0/en1" "true" "${lan_ip:-missing}" "Router port-forward target"
record_check "local_web_3000" "http://127.0.0.1:3000/" "true" "$(http_status http://127.0.0.1:3000/)" "React Web"
record_check "local_platform_8000" "http://127.0.0.1:8000/health" "true" "$(http_status http://127.0.0.1:8000/health)" "Platform API"
record_check "local_collection_8200" "http://127.0.0.1:8200/health" "true" "$(http_status http://127.0.0.1:8200/health)" "Collection API"
record_check "local_analysis_8100" "http://127.0.0.1:8100/health" "false" "$(http_status http://127.0.0.1:8100/health)" "Analysis debug endpoint"

origin_required="$([ "$EXPECT_ORIGIN_PROXY" = "1" ] && echo true || echo false)"
record_check "origin_http_80" "127.0.0.1:80" "$origin_required" "$(tcp_status 127.0.0.1 80)" "Caddy/Nginx HTTP listener"
record_check "origin_https_443" "127.0.0.1:443" "$origin_required" "$(tcp_status 127.0.0.1 443)" "Caddy/Nginx HTTPS listener"

domain_required="$([ "$EXPECT_DOMAIN_LIVE" = "1" ] && echo true || echo false)"
if [ -n "$ROOT_HOST" ]; then
  record_check "dns_root" "$ROOT_HOST" "$domain_required" "$(resolve_host "$ROOT_HOST")" "Cloudflare proxied records resolve to Cloudflare IPs, not origin IP"
fi
if [ -n "$WEB_HOST" ]; then
  record_check "dns_web" "$WEB_HOST" "$domain_required" "$(resolve_host "$WEB_HOST")" "Web hostname DNS"
  record_check "domain_web" "https://$WEB_HOST/" "$domain_required" "$(http_status "https://$WEB_HOST/")" "Web through Cloudflare"
fi
if [ -n "$PLATFORM_HOST" ]; then
  record_check "dns_platform" "$PLATFORM_HOST" "$domain_required" "$(resolve_host "$PLATFORM_HOST")" "Platform hostname DNS"
  record_check "domain_platform" "https://$PLATFORM_HOST/health" "$domain_required" "$(http_status "https://$PLATFORM_HOST/health")" "Platform through Cloudflare"
fi
if [ -n "$COLLECTION_HOST" ]; then
  record_check "dns_collection" "$COLLECTION_HOST" "$domain_required" "$(resolve_host "$COLLECTION_HOST")" "Collection hostname DNS"
  record_check "domain_collection" "https://$COLLECTION_HOST/health" "$domain_required" "$(http_status "https://$COLLECTION_HOST/health")" "Collection through Cloudflare"
fi

export JSON_OUT MD_OUT CHECKS_FILE public_ip lan_ip WEB_HOST PLATFORM_HOST COLLECTION_HOST ROOT_HOST
export EXPECT_ORIGIN_PROXY EXPECT_DOMAIN_LIVE
python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

checks = []
required_failures = []
warnings = []

for line in Path(os.environ["CHECKS_FILE"]).read_text(encoding="utf-8").splitlines():
    label, target, required, status, note = line.split("\t")
    is_required = required == "true"
    ok = bool(status and status not in {"000", "closed", "missing"})
    if label.startswith("local_") or label.startswith("domain_"):
        ok = status == "200"
    elif label.startswith("origin_"):
        ok = status == "open"
    item = {
        "label": label,
        "target": target,
        "required": is_required,
        "status": status,
        "ok": ok,
        "note": note,
    }
    checks.append(item)
    if is_required and not ok:
        required_failures.append(f"{label} is {status} for {target}")
    elif not is_required and not ok:
        warnings.append(f"{label} is {status} for {target}")

summary = {
    "kind": "ai_pms_cloudflare_dns_origin_doctor",
    "checked_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "status": "failed" if required_failures else "passed",
    "origin": {
        "public_ip": os.environ["public_ip"],
        "lan_ip": os.environ["lan_ip"],
    },
    "hostnames": {
        "root": os.environ["ROOT_HOST"],
        "web": os.environ["WEB_HOST"],
        "platform": os.environ["PLATFORM_HOST"],
        "collection": os.environ["COLLECTION_HOST"],
    },
    "expect_origin_proxy": os.environ["EXPECT_ORIGIN_PROXY"] == "1",
    "expect_domain_live": os.environ["EXPECT_DOMAIN_LIVE"] == "1",
    "recommended_dns_records": [
        {"type": "A", "name": "@", "content": os.environ["public_ip"], "proxied": True},
        {"type": "A", "name": "www", "content": os.environ["public_ip"], "proxied": True},
        {"type": "A", "name": "api", "content": os.environ["public_ip"], "proxied": True},
        {"type": "A", "name": "collection", "content": os.environ["public_ip"], "proxied": True},
    ],
    "recommended_router_forwarding": [
        {"external": 80, "internal_host": os.environ["lan_ip"], "internal_port": 80, "protocol": "tcp"},
        {"external": 443, "internal_host": os.environ["lan_ip"], "internal_port": 443, "protocol": "tcp"},
    ],
    "checks": checks,
    "required_failures": required_failures,
    "warnings": warnings,
}

Path(os.environ["JSON_OUT"]).write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lines = [
    "# Cloudflare DNS Origin Doctor",
    "",
    f"- Status: `{summary['status']}`",
    f"- Checked at: `{summary['checked_at']}`",
    f"- Public IP: `{summary['origin']['public_ip'] or '-'}`",
    f"- LAN IP: `{summary['origin']['lan_ip'] or '-'}`",
    "",
    "## Recommended DNS Records",
    "",
    "| Type | Name | Content | Proxy |",
    "|---|---|---|---|",
]
for record in summary["recommended_dns_records"]:
    lines.append(f"| {record['type']} | `{record['name']}` | `{record['content']}` | `{record['proxied']}` |")
lines += [
    "",
    "## Recommended Router Forwarding",
    "",
    "| External | Internal Host | Internal Port | Protocol |",
    "|---:|---|---:|---|",
]
for rule in summary["recommended_router_forwarding"]:
    lines.append(f"| {rule['external']} | `{rule['internal_host']}` | {rule['internal_port']} | {rule['protocol']} |")
lines += [
    "",
    "## Checks",
    "",
    "| Check | Required | Status | Target | Note |",
    "|---|---:|---|---|---|",
]
for check in checks:
    lines.append(f"| {check['label']} | {check['required']} | `{check['status']}` | `{check['target']}` | {check['note']} |")
if required_failures:
    lines += ["", "## Required Failures", ""]
    lines += [f"- {failure}" for failure in required_failures]
if warnings:
    lines += ["", "## Warnings", ""]
    lines += [f"- {warning}" for warning in warnings]
Path(os.environ["MD_OUT"]).write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"cloudflare_dns_origin={summary['status']}")
print(f"json={os.environ['JSON_OUT']}")
print(f"markdown={os.environ['MD_OUT']}")
if required_failures:
    raise SystemExit(1)
PY

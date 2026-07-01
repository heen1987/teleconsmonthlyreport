#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/runtime/lan_connectivity"
REPORT_JSON="${AIPMS_LAN_CONNECTIVITY_JSON:-$REPORT_DIR/latest_report.json}"
REPORT_MD="${AIPMS_LAN_CONNECTIVITY_MD:-$REPORT_DIR/latest_report.md}"
CHECKS_TSV="$REPORT_DIR/checks.tsv"
WEB_PORT="${AIPMS_WEB_PORT:-3000}"
REQUIRE_WEB="${AIPMS_LAN_REQUIRE_WEB:-0}"
EXPECT_ANALYSIS_PUBLIC="${AIPMS_LAN_EXPECT_ANALYSIS_PUBLIC:-0}"

mkdir -p "$REPORT_DIR"
: > "$CHECKS_TSV"

detect_lan_ip() {
  if [ -n "${LAN_IP:-}" ]; then
    printf '%s\n' "$LAN_IP"
    return 0
  fi

  local iface ip
  for iface in en1 en0; do
    if ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"; then
      if [ -n "$ip" ]; then
        printf '%s\n' "$ip"
        return 0
      fi
    fi
  done

  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{ print $1 }' || true)"
    if [ -n "$ip" ]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    ifconfig | awk '/inet / && $2 !~ /^127\./ { print $2; exit }'
    return 0
  fi

  return 1
}

add_check() {
  local name="$1"
  local status="$2"
  local required="$3"
  local detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$name" "$status" "$required" "$detail" >> "$CHECKS_TSV"
}

check_command() {
  local command="$1"
  if command -v "$command" >/dev/null 2>&1; then
    add_check "command_$command" "passed" "true" "$(command -v "$command")"
  else
    add_check "command_$command" "failed" "true" "$command not found"
  fi
}

http_status() {
  local url="$1"
  local body="$REPORT_DIR/$(echo "$url" | tr -c 'A-Za-z0-9' '_').body"
  curl -sS --connect-timeout 3 --max-time 8 -o "$body" -w '%{http_code}' "$url" 2>"$body.err" || true
}

check_http() {
  local name="$1"
  local url="$2"
  local required="$3"
  local status
  status="$(http_status "$url")"
  if [ "$status" = "200" ]; then
    add_check "$name" "passed" "$required" "$url -> HTTP $status"
  elif [ "$required" = "true" ]; then
    add_check "$name" "failed" "$required" "$url -> HTTP ${status:-curl_failed}"
  else
    add_check "$name" "warning" "$required" "$url -> HTTP ${status:-curl_failed}"
  fi
}

check_cors() {
  local origin="$1"
  local url="$2"
  local status body
  body="$REPORT_DIR/cors_preflight.body"
  status="$(
    curl -sS --connect-timeout 3 --max-time 8 -o "$body" -w '%{http_code}' \
      -X OPTIONS "$url" \
      -H "Origin: $origin" \
      -H "Access-Control-Request-Method: GET" \
      -H "Access-Control-Request-Headers: Authorization,Content-Type" \
      2>"$body.err" || true
  )"
  if [ "$status" = "200" ]; then
    add_check "platform_cors_from_lan_web" "passed" "true" "$origin -> $url"
  else
    add_check "platform_cors_from_lan_web" "failed" "true" "$origin -> $url HTTP ${status:-curl_failed}"
  fi
}

check_listener() {
  local name="$1"
  local port="$2"
  local required_public="$3"

  if ! command -v lsof >/dev/null 2>&1; then
    add_check "$name" "warning" "false" "lsof not available; listener address not inspected"
    return
  fi

  local output
  output="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [ -z "$output" ]; then
    if [ "$required_public" = "true" ]; then
      add_check "$name" "failed" "$required_public" "no listener on TCP $port"
    else
      add_check "$name" "warning" "$required_public" "no listener on TCP $port"
    fi
    return
  fi

  if printf '%s\n' "$output" | grep -E "TCP (\\*|0\\.0\\.0\\.0|\\[::\\]):${port} " >/dev/null; then
    if [ "$required_public" = "true" ]; then
      add_check "$name" "passed" "$required_public" "public listener on TCP $port"
    else
      add_check "$name" "warning" "$required_public" "public listener on TCP $port; direct client access is not required"
    fi
  elif [ "$required_public" = "true" ]; then
    add_check "$name" "failed" "$required_public" "listener exists but is not public: $(printf '%s' "$output" | tr '\n' ' ')"
  else
    add_check "$name" "passed" "$required_public" "local-only listener is acceptable on TCP $port"
  fi
}

read_env_value() {
  local path="$1"
  local key="$2"
  if [ -f "$path" ]; then
    awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2) }' "$path" | tail -1
  fi
}

check_command curl
check_command python3

LAN_IP="$(detect_lan_ip)"
if [ -z "$LAN_IP" ]; then
  add_check "lan_ip" "failed" "true" "LAN IP not found; set LAN_IP manually"
  LAN_IP="0.0.0.0"
else
  add_check "lan_ip" "passed" "true" "$LAN_IP"
fi

PLATFORM_URL="${PLATFORM_URL:-http://$LAN_IP:8000}"
COLLECTION_URL="${COLLECTION_URL:-http://$LAN_IP:8200}"
WEB_URL="${WEB_URL:-http://$LAN_IP:$WEB_PORT}"
ANALYSIS_URL="${ANALYSIS_URL:-http://$LAN_IP:8100}"

check_http "platform_local_health" "http://127.0.0.1:8000/health" "true"
check_http "collection_local_health" "http://127.0.0.1:8200/health" "true"
check_http "platform_lan_health" "$PLATFORM_URL/health" "true"
check_http "collection_lan_health" "$COLLECTION_URL/health" "true"

if [ "$REQUIRE_WEB" = "1" ]; then
  check_http "web_lan_home" "$WEB_URL/" "true"
else
  check_http "web_lan_home" "$WEB_URL/" "false"
fi

check_http "analysis_local_health_optional" "http://127.0.0.1:8100/health" "false"
if [ "$EXPECT_ANALYSIS_PUBLIC" = "1" ]; then
  check_http "analysis_lan_health" "$ANALYSIS_URL/health" "true"
else
  check_http "analysis_lan_health_optional" "$ANALYSIS_URL/health" "false"
fi

check_cors "$WEB_URL" "$PLATFORM_URL/users/me"
check_listener "platform_public_listener" "8000" "true"
check_listener "collection_public_listener" "8200" "true"
check_listener "analysis_listener_optional" "8100" "false"

backend_collection_url="$(read_env_value "$ROOT_DIR/backend/.env" "COLLECTION_API_URL")"
collection_platform_url="$(read_env_value "$ROOT_DIR/collection_api/.env" "PLATFORM_API_URL")"
analysis_collection_url="$(read_env_value "$ROOT_DIR/analysis_server/.env" "COLLECTION_API_URL")"

add_check "backend_collection_api_url" "passed" "false" "${backend_collection_url:-default http://localhost:8200}"
add_check "collection_platform_api_url" "passed" "false" "${collection_platform_url:-default http://localhost:8000}"
add_check "analysis_worker_collection_api_url" "passed" "false" "${analysis_collection_url:-default http://localhost:8200}"

export CHECKS_TSV REPORT_JSON REPORT_MD ROOT_DIR LAN_IP PLATFORM_URL COLLECTION_URL WEB_URL ANALYSIS_URL
python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

checks = []
for line in Path(os.environ["CHECKS_TSV"]).read_text(encoding="utf-8").splitlines():
    name, status, required, detail = line.split("\t", 3)
    checks.append(
        {
            "name": name,
            "status": status,
            "required": required == "true",
            "detail": detail,
        }
    )

required_failures = sum(1 for item in checks if item["required"] and item["status"] == "failed")
warnings = sum(1 for item in checks if item["status"] == "warning")
overall = "failed" if required_failures else ("warning" if warnings else "passed")

recommendations = []
if any(item["name"] == "platform_public_listener" and item["status"] == "failed" for item in checks):
    recommendations.append(
        "Start Platform with: AIPMS_PLATFORM_BIND_HOST=0.0.0.0 AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1 bash scripts/run_platform_backend.sh"
    )
if any(item["name"] == "collection_public_listener" and item["status"] == "failed" for item in checks):
    recommendations.append(
        "Start Collection with: AIPMS_COLLECTION_BIND_HOST=0.0.0.0 AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1 bash scripts/run_collection_api.sh"
    )
if any(item["name"] == "web_lan_home" and item["status"] in {"failed", "warning"} for item in checks):
    recommendations.append(
        f"Start Web with: cd web_client && VITE_API_BASE={os.environ['PLATFORM_URL']} npm run dev -- --host 0.0.0.0 --port 3000"
    )
recommendations.append(
    f"Build Android for LAN with: LAN_IP={os.environ['LAN_IP']} bash scripts/build_android_lan_debug.sh"
)

report = {
    "kind": "lan_connectivity_doctor",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "root": os.environ["ROOT_DIR"],
    "lan_ip": os.environ["LAN_IP"],
    "urls": {
        "web": os.environ["WEB_URL"],
        "platform": os.environ["PLATFORM_URL"],
        "collection": os.environ["COLLECTION_URL"],
        "analysis": os.environ["ANALYSIS_URL"],
    },
    "overall_status": overall,
    "required_failures": required_failures,
    "warnings": warnings,
    "checks": checks,
    "recommendations": recommendations,
}

Path(os.environ["REPORT_JSON"]).write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

lines = [
    "# AI-PMS LAN Connectivity Doctor",
    "",
    f"- status: `{overall}`",
    f"- lan_ip: `{os.environ['LAN_IP']}`",
    f"- web: `{os.environ['WEB_URL']}`",
    f"- platform: `{os.environ['PLATFORM_URL']}`",
    f"- collection: `{os.environ['COLLECTION_URL']}`",
    f"- analysis: `{os.environ['ANALYSIS_URL']}`",
    "",
    "## Checks",
    "",
]
for item in checks:
    marker = "required" if item["required"] else "optional"
    lines.append(f"- `{item['status']}` `{item['name']}` ({marker}): {item['detail']}")
lines.extend(["", "## Recommendations", ""])
lines.extend(f"- {item}" for item in recommendations)
Path(os.environ["REPORT_MD"]).write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"lan_connectivity_doctor={overall}")
print(f"json={os.environ['REPORT_JSON']}")
print(f"markdown={os.environ['REPORT_MD']}")
if overall == "failed":
    raise SystemExit(1)
PY

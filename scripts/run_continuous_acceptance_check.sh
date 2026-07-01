#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${AIPMS_CONTINUOUS_CHECK_DIR:-$ROOT_DIR/runtime/continuous_acceptance}"
REPORT_JSON="$REPORT_DIR/latest_report.json"
REPORT_MD="$REPORT_DIR/latest_report.md"
REQUIRE_PUBLIC_COLLECTION="${AIPMS_CONTINUOUS_REQUIRE_PUBLIC_COLLECTION:-1}"
REQUIRE_EXTERNAL_FLOW="${AIPMS_CONTINUOUS_REQUIRE_EXTERNAL_FLOW:-1}"
CHECK_PUBLIC_WEB="${AIPMS_CONTINUOUS_CHECK_PUBLIC_WEB:-0}"

mkdir -p "$REPORT_DIR"

export ROOT_DIR REPORT_JSON REPORT_MD REQUIRE_PUBLIC_COLLECTION REQUIRE_EXTERNAL_FLOW CHECK_PUBLIC_WEB

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
report_json = Path(os.environ["REPORT_JSON"])
report_md = Path(os.environ["REPORT_MD"])
require_public_collection = os.environ["REQUIRE_PUBLIC_COLLECTION"] == "1"
require_external_flow = os.environ["REQUIRE_EXTERNAL_FLOW"] == "1"
check_public_web = os.environ["CHECK_PUBLIC_WEB"] == "1"

checks: list[dict[str, object]] = []


def add(name: str, status: str, detail: str, *, required: bool = False) -> None:
    checks.append(
        {
            "name": name,
            "status": status,
            "required": required,
            "detail": detail,
        }
    )


def run(name: str, command: list[str], *, required: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=root, text=True, capture_output=True)
    detail = (result.stdout + result.stderr).strip()
    if result.returncode == 0:
        add(name, "passed", detail or "ok", required=required)
    else:
        add(name, "failed" if required else "warning", detail or f"exit={result.returncode}", required=required)
    return result


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        add(f"env_{path.parent.name}", "failed", f"missing: {path}", required=True)
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    add(f"env_{path.parent.name}", "passed", str(path), required=True)
    return values


def latest_tunnel_url(service: str) -> str:
    log = root / "runtime/tunnels" / f"{service}.log"
    if not log.exists():
        add(f"tunnel_log_{service}", "warning", f"missing: {log}")
        return ""
    matches = re.findall(r"https://[a-z0-9-]+\.trycloudflare\.com", log.read_text(errors="ignore"))
    if not matches:
        add(f"tunnel_log_{service}", "warning", f"no URL in {log}")
        return ""
    url = matches[-1].rstrip("/")
    add(f"tunnel_log_{service}", "passed", url)
    return url


def request(
    name: str,
    method: str,
    url: str,
    *,
    expected: int,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
    required: bool = True,
) -> None:
    req = urllib.request.Request(url, data=body, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.status
            content = response.read(500).decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        status = exc.code
        content = exc.read(500).decode("utf-8", errors="replace")
    except Exception as exc:  # noqa: BLE001 - report exact live connectivity failure.
        add(name, "failed" if required else "warning", f"{url} ({exc})", required=required)
        return
    if status == expected:
        add(name, "passed", f"HTTP {status} {url} {content[:160]}", required=required)
    else:
        add(name, "failed" if required else "warning", f"HTTP {status}, expected {expected}: {url} {content[:160]}", required=required)


run("collection_public_binding_guard", ["bash", "scripts/smoke_collection_public_binding_guard.sh"], required=True)
run("core_api_public_binding_guard", ["bash", "scripts/smoke_core_api_public_binding_guard.sh"], required=True)
run("web_public_binding_guard", ["bash", "scripts/smoke_web_public_binding_guard.sh"], required=True)
run("apk_publication_freshness", ["bash", "scripts/smoke_apk_publication_freshness.sh"], required=True)

backend_env = read_env(root / "backend/.env")
collection_env = read_env(root / "collection_api/.env")
analysis_env = read_env(root / "analysis_server/.env")

default_markers = {"dev-v1", "dev-collection-callback-secret", "change-me", ""}
callback_values = {
    "backend_callback_id": backend_env.get("COLLECTION_CALLBACK_SECRET_ID", ""),
    "backend_callback_secret": backend_env.get("COLLECTION_CALLBACK_SECRET", ""),
    "collection_callback_id": collection_env.get("PLATFORM_CALLBACK_SECRET_ID", ""),
    "collection_callback_secret": collection_env.get("PLATFORM_CALLBACK_SECRET", ""),
}
bad_callback = {key: value for key, value in callback_values.items() if value in default_markers}
if bad_callback:
    add("production_callback_secrets", "failed", f"default or empty values: {sorted(bad_callback)}", required=True)
else:
    add("production_callback_secrets", "passed", "callback secret/id values are non-default", required=True)

internal_values = {
    "backend": backend_env.get("COLLECTION_INTERNAL_API_SECRET", ""),
    "collection": collection_env.get("COLLECTION_INTERNAL_API_SECRET", ""),
    "analysis": analysis_env.get("COLLECTION_INTERNAL_API_SECRET", ""),
}
if any(value in default_markers for value in internal_values.values()) or len(set(internal_values.values())) != 1:
    invalid_keys = [
        key
        for key, value in internal_values.items()
        if value in default_markers
    ]
    add(
        "production_internal_secret_alignment",
        "failed",
        "invalid or mismatched internal secrets; "
        f"invalid_keys={invalid_keys}, services={sorted(internal_values)}",
        required=True,
    )
else:
    add("production_internal_secret_alignment", "passed", "backend/collection/analysis internal secrets match", required=True)

def check_local_port(name: str, port: int) -> None:
    lsof = subprocess.run(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"], text=True, capture_output=True)
    listen_output = (lsof.stdout + lsof.stderr).strip()
    if re.search(rf"TCP (\*|0\.0\.0\.0|\[::\]):{port} ", listen_output):
        add(name, "failed", listen_output, required=True)
    elif f"127.0.0.1:{port}" in listen_output:
        add(name, "passed", listen_output, required=True)
    else:
        add(name, "failed", listen_output or f"no listener on {port}", required=True)


check_local_port("collection_raw_public_port", 8200)
check_local_port("web_raw_public_port", 3000)

body = b'{"project_id":"CHECK","meeting_id":"CHECK-MTG"}'
json_headers = {"Content-Type": "application/json"}
request("collection_local_health", "GET", "http://127.0.0.1:8200/health", expected=200, required=True)
request("collection_local_upload_unauth", "POST", "http://127.0.0.1:8200/upload-sessions", expected=401, body=body, headers=json_headers, required=True)
request(
    "collection_local_upload_wrong_internal",
    "POST",
    "http://127.0.0.1:8200/upload-sessions",
    expected=403,
    body=body,
    headers={**json_headers, "X-Internal-Secret": "wrong"},
    required=True,
)
request(
    "collection_local_internal_list",
    "GET",
    "http://127.0.0.1:8200/analysis-jobs?limit=1",
    expected=200,
    headers={"X-Internal-Secret": internal_values.get("backend", "")},
    required=True,
)

collection_public = latest_tunnel_url("collection")
service_urls = {"collection": collection_public}
if collection_public:
    request("collection_public_health", "GET", f"{collection_public}/health", expected=200, required=require_public_collection)
    request(
        "collection_public_upload_unauth",
        "POST",
        f"{collection_public}/upload-sessions",
        expected=401,
        body=body,
        headers=json_headers,
        required=require_public_collection,
    )
else:
    add(
        "collection_public_url",
        "failed" if require_public_collection else "warning",
        "missing public Collection tunnel URL",
        required=require_public_collection,
    )

for service, path in (("platform", "/health"), ("analysis", "/health")):
    url = latest_tunnel_url(service)
    service_urls[service] = url
    if url:
        request(f"{service}_public_health", "GET", f"{url}{path}", expected=200, required=False)

if check_public_web:
    web_url = latest_tunnel_url("web")
    service_urls["web"] = web_url
    if web_url:
        request("web_public_health", "GET", f"{web_url}/", expected=200, required=False)
else:
    configured_web_url = os.environ.get("AIPMS_PUBLIC_WEB_URL", "").rstrip("/")
    service_urls["web"] = configured_web_url
    add(
        "web_public_health",
        "passed",
        configured_web_url
        or "quick-tunnel Web check skipped; Web is expected through GitHub Pages or local runtime",
        required=False,
    )

external_flow_path = root / "runtime/public_handoff/latest_external_flow_check.json"
if not external_flow_path.exists():
    add(
        "public_external_flow_latest",
        "failed" if require_external_flow else "warning",
        f"missing: {external_flow_path}",
        required=require_external_flow,
    )
else:
    try:
        external_flow = json.loads(external_flow_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report unreadable evidence exactly.
        add(
            "public_external_flow_latest",
            "failed" if require_external_flow else "warning",
            f"unreadable: {external_flow_path} ({exc})",
            required=require_external_flow,
        )
    else:
        expected_values = {
            "public_external_flow": "passed",
            "job_status": "completed",
            "platform_callback_status": "succeeded",
            "meeting_status": "review_required",
            "review_status_code": 200,
        }
        mismatches = [
            f"{key}={external_flow.get(key)!r}"
            for key, expected in expected_values.items()
            if external_flow.get(key) != expected
        ]
        expected_urls = {
            "web_url": service_urls.get("web", ""),
            "platform_url": service_urls.get("platform", ""),
            "collection_url": service_urls.get("collection", ""),
            "analysis_url": service_urls.get("analysis", ""),
        }
        url_mismatches = [
            f"{key}={external_flow.get(key)!r} expected={expected!r}"
            for key, expected in expected_urls.items()
            if expected and external_flow.get(key) != expected
        ]
        review_counts = external_flow.get("review_counts") or {}
        missing_review_counts = [
            key
            for key in ("transcript_segments", "decisions", "action_items", "risks", "required_resources")
            if int(review_counts.get(key) or 0) < 1
        ]
        if mismatches or url_mismatches or missing_review_counts:
            detail_parts = []
            if mismatches:
                detail_parts.append("status mismatch: " + ", ".join(mismatches))
            if url_mismatches:
                detail_parts.append("URL mismatch: " + ", ".join(url_mismatches))
            if missing_review_counts:
                detail_parts.append("missing review counts: " + ", ".join(missing_review_counts))
            add(
                "public_external_flow_latest",
                "failed" if require_external_flow else "warning",
                "; ".join(detail_parts),
                required=require_external_flow,
            )
        else:
            add(
                "public_external_flow_latest",
                "passed",
                (
                    f"job={external_flow.get('job_id')} "
                    f"analysis={external_flow.get('analysis_id')} "
                    f"meeting={external_flow.get('meeting_id')}"
                ),
                required=require_external_flow,
            )

for script in (
    "scripts/doctor_local_environment.sh",
    "scripts/doctor_public_handoff.sh",
    "scripts/smoke_user_facing_copy_guard.sh",
    "scripts/smoke_apk_publication_freshness.sh",
):
    if (root / script).exists():
        add(f"script_present_{Path(script).name}", "passed", script)
    else:
        add(f"script_present_{Path(script).name}", "warning", f"missing: {script}")

required_failures = [check for check in checks if check["required"] and check["status"] == "failed"]
warnings = [check for check in checks if check["status"] == "warning"]
overall = "failed" if required_failures else "warning" if warnings else "passed"

report = {
    "kind": "continuous_acceptance_check",
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "overall_status": overall,
    "required_failures": len(required_failures),
    "warnings": len(warnings),
    "checks": checks,
}
report_json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lines = [
    "# AI-PMS Continuous Acceptance Check",
    "",
    f"- status: `{overall}`",
    f"- required_failures: `{len(required_failures)}`",
    f"- warnings: `{len(warnings)}`",
    f"- generated_at: `{report['generated_at']}`",
    "",
    "## Checks",
    "",
    "| status | required | name | detail |",
    "|---|---:|---|---|",
]
for check in checks:
    detail = str(check["detail"]).replace("|", "\\|").replace("\n", " ")
    lines.append(f"| `{check['status']}` | `{check['required']}` | `{check['name']}` | {detail[:500]} |")
report_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"continuous_acceptance_check={overall}")
print(f"json={report_json}")
print(f"markdown={report_md}")
if required_failures:
    sys.exit(1)
PY

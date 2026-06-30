#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="${AIPMS_PUBLIC_HANDOFF_DOCTOR_JSON:-$ROOT_DIR/runtime/public_handoff/latest_doctor.json}"
REPORT_MD_PATH="${AIPMS_PUBLIC_HANDOFF_DOCTOR_MD:-$ROOT_DIR/runtime/public_handoff/latest_doctor.md}"
STRICT="${AIPMS_PUBLIC_HANDOFF_DOCTOR_STRICT:-0}"

mkdir -p "$(dirname "$REPORT_PATH")"
mkdir -p "$(dirname "$REPORT_MD_PATH")"

export ROOT_DIR REPORT_PATH REPORT_MD_PATH STRICT

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import shutil
import socket
import sys
import urllib.parse
import urllib.request
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
report_path = Path(os.environ["REPORT_PATH"])
report_md_path = Path(os.environ["REPORT_MD_PATH"])
strict = os.environ["STRICT"] == "1"

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


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path, label: str, *, required: bool = True) -> dict[str, object]:
    if not path.exists():
        add(label, "failed" if required else "warning", f"missing: {path}", required=required)
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report exact parse error to the operator.
        add(label, "failed", f"invalid JSON: {path} ({exc})", required=required)
        return {}
    add(label, "passed", f"valid JSON: {path}", required=required)
    return data if isinstance(data, dict) else {}


def file_check(path: Path, label: str, min_bytes: int = 1, *, required: bool = True) -> bool:
    if not path.exists():
        add(label, "failed" if required else "warning", f"missing: {path}", required=required)
        return False
    size = path.stat().st_size
    if size < min_bytes:
        add(label, "failed", f"too small: {path} ({size} bytes)", required=required)
        return False
    add(label, "passed", f"{path} ({size} bytes)", required=required)
    return True


def host_from_url(url: str) -> str:
    return urllib.parse.urlparse(url).hostname or ""


def dns_check(url: str, label: str) -> None:
    host = host_from_url(url)
    if not host:
        add(label, "warning", f"missing hostname in URL: {url}")
        return
    try:
        socket.getaddrinfo(host, 443)
    except OSError as exc:
        add(label, "warning", f"DNS unresolved: {host} ({exc})")
        return
    add(label, "passed", f"DNS resolved: {host}")


def local_health(url: str, label: str) -> None:
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            status = response.status
    except Exception as exc:  # noqa: BLE001 - local services may be intentionally stopped.
        add(label, "warning", f"not reachable: {url} ({exc})")
        return
    if status == 200:
        add(label, "passed", f"{url} returned 200")
    else:
        add(label, "warning", f"{url} returned HTTP {status}")


def latest_tunnel_url(service: str) -> str:
    log_path = root / "runtime/tunnels" / f"{service}.log"
    if not log_path.exists():
        add(f"tunnel_log_{service}", "warning", f"missing: {log_path}")
        return ""
    matches = re.findall(r"https://[a-z0-9-]+\.trycloudflare\.com", log_path.read_text(errors="ignore"))
    if not matches:
        add(f"tunnel_log_{service}", "warning", f"no quick-tunnel URL in {log_path}")
        return ""
    url = matches[-1]
    add(f"tunnel_log_{service}", "passed", url)
    return url


review_package_path = root / "web_client/public/handoff/public-review-package.json"
execution_json_path = root / "web_client/public/run/execution.json"
apk_metadata_path = root / "web_client/public/downloads/android-apk.json"
requirements_path = root / "web_client/public/requirements/requirements.json"
refresh_summary_path = root / "runtime/public_handoff/latest_refresh.json"

review_package = read_json(review_package_path, "review_package_json")
execution_json = read_json(execution_json_path, "execution_json")
apk_metadata = read_json(apk_metadata_path, "apk_metadata_json")
requirements = read_json(requirements_path, "requirements_manifest_json")
refresh_summary = read_json(refresh_summary_path, "refresh_summary_json", required=False)

file_check(root / "web_client/public/handoff/index.html", "handoff_index_html", 1000)
file_check(root / "web_client/public/run/index.html", "run_index_html", 1000)
file_check(root / "web_client/public/downloads/install.html", "apk_install_guide_html", 1000)
file_check(root / "web_client/public/downloads/AI-PMS-Recorder.apk", "public_apk_alias", 1_000_000)
file_check(root / "../배포_APK/AI-PMS-Recorder.apk", "drive_direct_apk", 1_000_000, required=False)
file_check(root / "web_client/public/requirements/AI-PMS-requirements-v0.2.docx", "public_requirements_docx", 20_000)
file_check(root / "web_client/public/requirements/AI-PMS-requirements-v0.2.md", "public_requirements_markdown", 5_000)

if apk_metadata:
    alias_path = root / "web_client/public/downloads" / str(apk_metadata.get("apk_alias", "AI-PMS-Recorder.apk"))
    build_path = root / "web_client/public/downloads" / str(apk_metadata.get("apk", ""))
    expected = str(apk_metadata.get("sha256", ""))
    for label, path in (("apk_alias_sha256", alias_path), ("apk_build_sha256", build_path)):
        if path.exists() and expected:
            actual = sha256(path)
            add(label, "passed" if actual == expected else "failed", f"{actual} expected {expected}", required=True)

if requirements:
    public_files = requirements.get("public_files", {})
    if isinstance(public_files, dict):
        docx_info = public_files.get("docx", {})
        md_info = public_files.get("markdown", {})
        if isinstance(docx_info, dict):
            docx_path = root / "web_client/public/requirements" / str(docx_info.get("file_name", ""))
            expected_docx = str(docx_info.get("sha256", ""))
            if docx_path.exists() and expected_docx:
                actual_docx = sha256(docx_path)
                add(
                    "requirements_docx_sha256",
                    "passed" if actual_docx == expected_docx else "failed",
                    f"{actual_docx} expected {expected_docx}",
                    required=True,
                )
        if isinstance(md_info, dict):
            md_path = root / "web_client/public/requirements" / str(md_info.get("file_name", ""))
            expected_md = str(md_info.get("sha256", ""))
            if md_path.exists() and expected_md:
                actual_md = sha256(md_path)
                add(
                    "requirements_markdown_sha256",
                    "passed" if actual_md == expected_md else "failed",
                    f"{actual_md} expected {expected_md}",
                    required=True,
                )

for package_name, data in (("review_package", review_package), ("execution_json", execution_json)):
    text = json.dumps(data, ensure_ascii=False)
    for marker in (
        "requirements_docx",
        "AI-PMS-requirements-v0.2.docx",
        "AI-PMS-Recorder.apk",
        "public_review_package" if package_name == "review_package" else "public_execution_hub",
    ):
        add(
            f"{package_name}_marker_{marker}",
            "passed" if marker in text else "failed",
            marker,
            required=True,
        )

public_urls = review_package.get("public_urls", {}) if isinstance(review_package, dict) else {}
if isinstance(public_urls, dict):
    for key in ("web_console", "platform_docs", "collection_docs", "analysis_docs", "run_hub", "apk_file"):
        url = str(public_urls.get(key, ""))
        if url:
            dns_check(url, f"public_dns_{key}")
        else:
            add(f"public_dns_{key}", "warning", "missing URL")

for service in ("web", "platform", "collection", "analysis"):
    url = latest_tunnel_url(service)
    if url:
        dns_check(url, f"tunnel_dns_{service}")

for command in ("cloudflared", "screen", "curl"):
    add(
        f"command_{command}",
        "passed" if shutil.which(command) else "warning",
        shutil.which(command) or "not found",
    )

for label, url in (
    ("local_web", "http://127.0.0.1:3000/"),
    ("local_platform", "http://127.0.0.1:8000/health"),
    ("local_collection", "http://127.0.0.1:8200/health"),
    ("local_analysis", "http://127.0.0.1:8100/health"),
):
    local_health(url, label)

public_smoke_status = str(refresh_summary.get("public_smoke_status", "unknown")) if refresh_summary else "unknown"
if public_smoke_status == "passed":
    add("latest_public_smoke", "passed", "latest refresh summary public_smoke_status=passed")
elif public_smoke_status == "failed":
    add("latest_public_smoke", "warning", "latest refresh summary public_smoke_status=failed")
else:
    add("latest_public_smoke", "warning", f"latest refresh summary public_smoke_status={public_smoke_status}")

recommendations = [
    "For a new quick tunnel: RESTART_PUBLIC_TUNNELS=1 AIPMS_REFRESH_START_TUNNELS=1 bash scripts/refresh_public_handoff_bundle.sh",
    "For strict live verification: AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1 bash scripts/refresh_public_handoff_bundle.sh",
    "For fixed URLs: bash scripts/prepare_cloudflare_named_tunnel.sh && bash scripts/run_cloudflare_named_tunnel.sh",
]

required_failures = [check for check in checks if check["required"] and check["status"] == "failed"]
warnings = [check for check in checks if check["status"] == "warning"]
overall = "failed" if required_failures else "warning" if warnings else "passed"

report = {
    "kind": "public_handoff_doctor",
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "overall_status": overall,
    "public_smoke_status": public_smoke_status,
    "required_failures": len(required_failures),
    "warnings": len(warnings),
    "checks": checks,
    "recommendations": recommendations,
}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def md_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


visible_checks = [check for check in checks if check["status"] != "passed"]
if not visible_checks:
    visible_checks = checks

md_lines = [
    "# AI-PMS Public Handoff Doctor",
    "",
    f"- generated_at: `{report['generated_at']}`",
    f"- overall_status: `{overall}`",
    f"- public_smoke_status: `{public_smoke_status}`",
    f"- required_failures: `{len(required_failures)}`",
    f"- warnings: `{len(warnings)}`",
    "",
    "## Attention Checks",
    "",
    "| status | required | name | detail |",
    "| --- | --- | --- | --- |",
]
for check in visible_checks:
    md_lines.append(
        "| "
        + " | ".join(
            (
                md_cell(check["status"]),
                md_cell(check["required"]),
                md_cell(check["name"]),
                md_cell(check["detail"]),
            )
        )
        + " |"
    )

md_lines.extend(["", "## Next Commands", ""])
for recommendation in recommendations:
    md_lines.append(f"- `{recommendation}`")

md_lines.extend(["", "## Machine Report", "", f"- JSON: `{report_path}`"])
report_md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

print(f"public_handoff_doctor={overall}")
print(f"report={report_path}")
print(f"markdown={report_md_path}")
print(f"required_failures={len(required_failures)} warnings={len(warnings)}")
for recommendation in recommendations:
    print(f"next={recommendation}")

if strict and overall != "passed":
    sys.exit(1)
PY

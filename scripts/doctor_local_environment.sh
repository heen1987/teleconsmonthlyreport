#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="${AIPMS_LOCAL_ENV_DOCTOR_JSON:-$ROOT_DIR/runtime/local_environment/latest_doctor.json}"
REPORT_MD_PATH="${AIPMS_LOCAL_ENV_DOCTOR_MD:-$ROOT_DIR/runtime/local_environment/latest_doctor.md}"
STRICT="${AIPMS_LOCAL_ENV_DOCTOR_STRICT:-0}"

mkdir -p "$(dirname "$REPORT_PATH")"
mkdir -p "$(dirname "$REPORT_MD_PATH")"

export ROOT_DIR REPORT_PATH REPORT_MD_PATH STRICT

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import shutil
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
report_path = Path(os.environ["REPORT_PATH"])
report_md_path = Path(os.environ["REPORT_MD_PATH"])
strict = os.environ["STRICT"] == "1"
drive_root = root.parent
web_cache = Path(
    os.environ.get("AIPMS_WEB_NODE_MODULES_CACHE", str(Path.home() / ".cache/ai-pms/web_client"))
)

checks: list[dict[str, object]] = []
recommendations: list[str] = []


def add(name: str, status: str, detail: str, *, required: bool = False) -> None:
    checks.append({"name": name, "status": status, "required": required, "detail": detail})


def check_path(name: str, path: Path, *, required: bool = True, executable: bool = False, min_bytes: int = 0) -> None:
    if not path.exists():
        add(name, "failed" if required else "warning", f"missing: {path}", required=required)
        return
    if executable and not os.access(path, os.X_OK):
        add(name, "failed" if required else "warning", f"not executable: {path}", required=required)
        return
    if min_bytes and path.is_file() and path.stat().st_size < min_bytes:
        add(name, "failed" if required else "warning", f"too small: {path}", required=required)
        return
    add(name, "passed", str(path), required=required)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


check_path("drive_source_root", drive_root, required=True)
for directory in ("backend", "collection_api", "analysis_server", "android_client", "web_client", "contracts", "scripts"):
    check_path(f"dir_{directory}", root / directory, required=True)

check_path("backend_python", root / "backend/.venv/bin/python", required=True, executable=True)
check_path("collection_python", root / "collection_api/.venv/bin/python", required=True, executable=True)
check_path("analysis_python", root / "analysis_server/.venv/bin/python", required=True, executable=True)

for command in ("python3", "bash", "rg"):
    path = shutil.which(command)
    if path:
        add(f"command_{command}", "passed", path, required=True)
    else:
        add(f"command_{command}", "failed", f"{command} not found", required=True)

cached_vite = web_cache / "node_modules/vite/bin/vite.js"
if cached_vite.exists() and os.access(cached_vite, os.X_OK) and cached_vite.stat().st_size > 0:
    add("web_vite_dependency", "passed", f"cached Vite: {cached_vite}")
else:
    add(
        "web_vite_dependency",
        "warning",
        "cached Vite is missing; run scripts/repair_web_dependencies.sh before Web build verification",
    )
    recommendations.append("Run `bash scripts/repair_web_dependencies.sh` to refresh cached Web dependencies outside Google Drive.")

pending_node_modules = sorted(root.glob("web_client/.node_modules_delete_pending_*"))
if pending_node_modules:
    add(
        "pending_node_modules_cleanup",
        "warning",
        ", ".join(str(path.relative_to(root)) for path in pending_node_modules),
    )
    recommendations.append("Delete `.node_modules_delete_pending_*` after Google Drive releases file locks.")
else:
    add("pending_node_modules_cleanup", "passed", "none")

cache_paths = [
    path
    for path in (
        root / "backend/app/__pycache__",
        root / "collection_api/app/__pycache__",
        root / "analysis_server/app/__pycache__",
        root / "scripts/__pycache__",
    )
    if path.exists()
]
if cache_paths:
    add("python_cache_cleanup", "passed", "runtime-generated caches ignored")
else:
    add("python_cache_cleanup", "passed", "none")

ds_store_paths = [path for path in (root / "scripts").glob(".DS_Store")]
if ds_store_paths:
    add("macos_metadata_cleanup", "warning", ", ".join(str(path.relative_to(root)) for path in ds_store_paths))
    recommendations.append("Remove `.DS_Store` files from script/source folders.")
else:
    add("macos_metadata_cleanup", "passed", "none")

apk = drive_root / "배포_APK/AI-PMS-Recorder.apk"
apk_sha = drive_root / "배포_APK/AI-PMS-Recorder.sha256"
check_path("direct_apk", apk, required=True, min_bytes=1_000_000)
check_path("direct_apk_sha256_file", apk_sha, required=True, min_bytes=32)
if apk.exists() and apk_sha.exists():
    actual = sha256(apk)
    expected = apk_sha.read_text(encoding="utf-8").split()[0]
    if actual == expected:
        add("direct_apk_sha256", "passed", actual, required=True)
    else:
        add("direct_apk_sha256", "failed", f"expected {expected}, got {actual}", required=True)

for script in (
    "verify_mvp_static.sh",
    "smoke_screen_design_ui.sh",
    "smoke_user_facing_copy_guard.sh",
    "doctor_public_handoff.sh",
    "build_web_client_static.sh",
):
    check_path(f"script_{script}", root / "scripts" / script, required=True, executable=True)

required_failures = sum(1 for check in checks if check["required"] and check["status"] == "failed")
warnings = sum(1 for check in checks if check["status"] == "warning")
overall = "passed"
if required_failures:
    overall = "failed"
elif warnings:
    overall = "warning"
if strict and warnings and overall != "failed":
    overall = "failed"
    recommendations.append("Unset `AIPMS_LOCAL_ENV_DOCTOR_STRICT=1` to allow warning-only local checks.")

report = {
    "kind": "local_environment_doctor",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "root": str(root),
    "drive_root": str(drive_root),
    "overall_status": overall,
    "required_failures": required_failures,
    "warnings": warnings,
    "checks": checks,
    "recommendations": recommendations,
}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lines = [
    "# AI-PMS Local Environment Doctor",
    "",
    f"- status: `{overall}`",
    f"- required_failures: `{required_failures}`",
    f"- warnings: `{warnings}`",
    f"- root: `{root}`",
    "",
    "## Checks",
    "",
]
for check in checks:
    marker = "required" if check["required"] else "optional"
    lines.append(f"- `{check['status']}` `{check['name']}` ({marker}): {check['detail']}")
if recommendations:
    lines.extend(["", "## Recommendations", ""])
    lines.extend(f"- {item}" for item in recommendations)
report_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"local_environment_doctor={overall}")
print(f"json={report_path}")
print(f"markdown={report_md_path}")
if overall == "failed":
    raise SystemExit(1)
PY

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json
from pathlib import Path

root = Path.cwd()
direct_apk_dir = root.parent / "배포_APK"

artifact = root / "artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"
web_long = root / "web_client/public/downloads/AiPmsAndroidClient-responsive-public-debug.apk"
web_alias = root / "web_client/public/downloads/AI-PMS-Recorder.apk"
drive_direct = direct_apk_dir / "AI-PMS-Recorder.apk"
metadata_path = root / "web_client/public/downloads/android-apk.json"
direct_sha_path = direct_apk_dir / "AI-PMS-Recorder.sha256"
direct_manifest_path = direct_apk_dir / "apk_manifest.json"
install_report_path = direct_apk_dir / "설치검증_리포트.md"
run_manifest_path = root / "web_client/public/run/execution.json"
handoff_package_path = root / "web_client/public/handoff/public-review-package.json"
refresh_summary_path = root / "runtime/public_handoff/latest_refresh.json"
install_check_path = root / "runtime/android_public_install/latest_install_check.json"
portfolio_summary_path = root / "runtime/portfolio_evidence/latest_portfolio_evidence.json"

required_files = [
    artifact,
    web_long,
    web_alias,
    drive_direct,
    metadata_path,
    direct_sha_path,
    direct_manifest_path,
    install_report_path,
    run_manifest_path,
    handoff_package_path,
]

missing = [str(path) for path in required_files if not path.exists()]
if missing:
    raise SystemExit("missing APK publication files: " + ", ".join(missing))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


artifact_sha = sha256(artifact)
artifact_size = artifact.stat().st_size

for label, path in {
    "web_long": web_long,
    "web_alias": web_alias,
    "drive_direct": drive_direct,
}.items():
    if sha256(path) != artifact_sha or path.stat().st_size != artifact_size:
        raise SystemExit(
            f"{label} APK does not match artifact: "
            f"{path} size={path.stat().st_size} sha256={sha256(path)}"
        )

metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
if metadata.get("sha256") != artifact_sha or metadata.get("size_bytes") != artifact_size:
    raise SystemExit("web APK metadata does not match artifact")
if metadata.get("apk_alias") != "AI-PMS-Recorder.apk":
    raise SystemExit("web APK metadata alias is not AI-PMS-Recorder.apk")
if metadata.get("layout") != "responsive_phone_tablet":
    raise SystemExit("web APK metadata layout is not responsive_phone_tablet")

direct_sha_text = direct_sha_path.read_text(encoding="utf-8")
if artifact_sha not in direct_sha_text:
    raise SystemExit("direct Drive APK SHA file does not contain current artifact hash")

direct_manifest = json.loads(direct_manifest_path.read_text(encoding="utf-8"))
if direct_manifest.get("sha256") != artifact_sha or direct_manifest.get("size_bytes") != artifact_size:
    raise SystemExit("direct Drive APK manifest does not match artifact")
if direct_manifest.get("flow_policy") != "project_only_recording_auto_project_member_distribution":
    raise SystemExit("direct Drive APK manifest flow policy is wrong")

install_report = install_report_path.read_text(encoding="utf-8")
if artifact_sha not in install_report:
    raise SystemExit("install verification report does not contain current artifact hash")

run_manifest = json.loads(run_manifest_path.read_text(encoding="utf-8"))
if run_manifest.get("android_apk", {}).get("sha256") != artifact_sha:
    raise SystemExit("execution hub manifest APK hash does not match artifact")

handoff_package = json.loads(handoff_package_path.read_text(encoding="utf-8"))
if handoff_package.get("android_apk", {}).get("sha256") != artifact_sha:
    raise SystemExit("public handoff package APK hash does not match artifact")

optional_json_hash_paths = {
    "refresh_summary": refresh_summary_path,
    "install_check": install_check_path,
    "portfolio_summary": portfolio_summary_path,
}
for label, path in optional_json_hash_paths.items():
    if not path.exists():
        continue
    payload = json.loads(path.read_text(encoding="utf-8"))
    if label == "refresh_summary":
        observed = payload.get("android_apk", {}).get("sha256")
    elif label == "install_check":
        observed = payload.get("apk", {}).get("sha256")
    else:
        observed = payload.get("apk", {}).get("sha256")
    if observed != artifact_sha:
        raise SystemExit(f"{label} APK hash does not match artifact")

print(f"APK publication freshness passed: sha256={artifact_sha} size={artifact_size}")
PY

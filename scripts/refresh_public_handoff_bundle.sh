#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_DIR="$ROOT_DIR/runtime/public_handoff"
SUMMARY_JSON="$SUMMARY_DIR/latest_refresh.json"
APK_SOURCE="$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"

AIPMS_REFRESH_START_TUNNELS="${AIPMS_REFRESH_START_TUNNELS:-0}"
AIPMS_REFRESH_BUILD_APK="${AIPMS_REFRESH_BUILD_APK:-0}"
AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE="${AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE:-0}"

mkdir -p "$SUMMARY_DIR"

if [ "$AIPMS_REFRESH_START_TUNNELS" = "1" ]; then
  "$ROOT_DIR/scripts/run_public_tunnels.sh"
fi

"$ROOT_DIR/scripts/print_public_urls.sh" | tee "$SUMMARY_DIR/public_urls.txt"

if [ "$AIPMS_REFRESH_BUILD_APK" = "1" ]; then
  "$ROOT_DIR/scripts/build_android_public_debug.sh"
elif [ ! -f "$APK_SOURCE" ]; then
  echo "APK not found: $APK_SOURCE" >&2
  echo "Run with AIPMS_REFRESH_BUILD_APK=1 or run scripts/build_android_public_debug.sh first." >&2
  exit 1
fi

"$ROOT_DIR/scripts/publish_android_apk_download.sh"
"$ROOT_DIR/scripts/publish_public_review_package.sh"
"$ROOT_DIR/scripts/publish_public_execution_hub.sh"

SMOKE_STATUS="passed"
SMOKE_EXIT_CODE="0"
if SMOKE_OUTPUT="$("$ROOT_DIR/scripts/smoke_public_access.sh" 2>&1)"; then
  :
else
  SMOKE_EXIT_CODE="$?"
  SMOKE_STATUS="failed"
fi
case "$SMOKE_OUTPUT" in
  \{*) ;;
  *)
    if [ "$SMOKE_STATUS" = "passed" ]; then
      SMOKE_EXIT_CODE="1"
      SMOKE_STATUS="failed"
    fi
    ;;
esac
printf "%s\n" "$SMOKE_OUTPUT" | tee "$SUMMARY_DIR/latest_smoke.txt"

export ROOT_DIR SUMMARY_JSON SMOKE_OUTPUT SMOKE_STATUS SMOKE_EXIT_CODE
export AIPMS_REFRESH_START_TUNNELS AIPMS_REFRESH_BUILD_APK AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE

python3 - <<'PY'
from __future__ import annotations

import ast
import datetime as dt
import json
import os
from pathlib import Path

root_dir = Path(os.environ["ROOT_DIR"])
summary_json = Path(os.environ["SUMMARY_JSON"])
review_package_path = root_dir / "web_client/public/handoff/public-review-package.json"
apk_metadata_path = root_dir / "web_client/public/downloads/android-apk.json"
requirements_metadata_path = root_dir / "web_client/public/requirements/requirements.json"

review_package = json.loads(review_package_path.read_text(encoding="utf-8"))
apk_metadata = json.loads(apk_metadata_path.read_text(encoding="utf-8"))
requirements_metadata = json.loads(requirements_metadata_path.read_text(encoding="utf-8"))
smoke_status = os.environ["SMOKE_STATUS"]
raw_smoke_output = os.environ["SMOKE_OUTPUT"]
try:
    smoke: object = ast.literal_eval(raw_smoke_output)
    if not isinstance(smoke, dict):
        raise ValueError("public smoke output was not a dict")
except Exception:
    smoke_status = "failed"
    smoke = {
        "status": "failed",
        "exit_code": int(os.environ["SMOKE_EXIT_CODE"]),
        "output_tail": raw_smoke_output.splitlines()[-25:],
        "note": "Public tunnel smoke failed; refresh summary was still written for handoff traceability.",
    }

summary = {
    "kind": "public_handoff_refresh_summary",
    "refreshed_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "started_tunnels": os.environ["AIPMS_REFRESH_START_TUNNELS"] == "1",
    "rebuilt_apk": os.environ["AIPMS_REFRESH_BUILD_APK"] == "1",
    "public_smoke_status": smoke_status,
    "public_smoke_required": os.environ["AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE"] == "1",
    "public_urls": review_package["public_urls"],
    "execution_hub_url": review_package["public_urls"]["run_hub"],
    "response_template_url": review_package["response_template"]["url"],
    "response_collection": review_package["response_collection"],
    "android_apk": {
        "file_name": apk_metadata["apk"],
        "sha256": apk_metadata["sha256"],
        "size_bytes": apk_metadata["size_bytes"],
        "layout": apk_metadata["layout"],
        "signing": apk_metadata["signing"],
        "download_url": review_package["android_apk"]["download_url"],
        "install_guide_url": review_package["android_apk"]["install_guide_url"],
    },
    "requirements": {
        "version": requirements_metadata["version"],
        "title": requirements_metadata["title"],
        "docx_url": review_package["requirements"]["docx_url"],
        "markdown_url": review_package["requirements"]["markdown_url"],
        "docx_sha256": requirements_metadata["public_files"]["docx"]["sha256"],
        "markdown_sha256": requirements_metadata["public_files"]["markdown"]["sha256"],
    },
    "smoke": smoke,
    "next_manual_checks": [
        "Install the APK on one phone-width device and one tablet-width device.",
        "Run one recording upload to Collection API and confirm analysis job status.",
        "Have each owner respond against the review_scopes in the public review package.",
    ],
}

summary_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat <<EOF
Public handoff bundle refreshed.

Summary:
  $SUMMARY_JSON

Review package:
  /handoff/public-review-package.json
EOF

if [ "$AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE" = "1" ] && [ "$SMOKE_STATUS" != "passed" ]; then
  echo "Public smoke failed and AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1." >&2
  exit "$SMOKE_EXIT_CODE"
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="${APK_PATH:-$ROOT_DIR/web_client/public/downloads/AiPmsAndroidClient-responsive-public-debug.apk}"
PACKAGE_NAME="com.aipms"
MAIN_ACTIVITY="com.aipms/.MainActivity"
SUMMARY_DIR="$ROOT_DIR/runtime/android_public_install"
SUMMARY_JSON="$SUMMARY_DIR/latest_install_check.json"
SUMMARY_MD="$SUMMARY_DIR/latest_install_check.md"
DIRECT_APK_DIR="${DIRECT_APK_DIR:-$ROOT_DIR/../배포_APK}"
DIRECT_REPORT_MD="$DIRECT_APK_DIR/설치검증_리포트.md"

AIPMS_ANDROID_INSTALL_DRY_RUN="${AIPMS_ANDROID_INSTALL_DRY_RUN:-0}"
AIPMS_ALLOW_EMULATOR="${AIPMS_ALLOW_EMULATOR:-0}"
ADB_BIN="${ADB:-adb}"

export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

if [ ! -f "$APK" ]; then
  echo "APK not found: $APK" >&2
  echo "Run scripts/refresh_public_handoff_bundle.sh first." >&2
  exit 1
fi

mkdir -p "$SUMMARY_DIR" "$DIRECT_APK_DIR"

APK_SHA256="$(shasum -a 256 "$APK" | awk '{ print $1 }')"
APK_SIZE_BYTES="$(wc -c < "$APK" | tr -d ' ')"

write_summary() {
  local mode="$1"
  local device_serial="${2:-}"
  local install_status="${3:-not_run}"
  local wm_size="${4:-}"
  local wm_density="${5:-}"
  local android_release="${6:-}"
  local launch_status="${7:-not_run}"

  export SUMMARY_JSON SUMMARY_MD DIRECT_REPORT_MD APK APK_SHA256 APK_SIZE_BYTES PACKAGE_NAME MAIN_ACTIVITY
  export mode device_serial install_status wm_size wm_density android_release launch_status
  export AIPMS_ANDROID_INSTALL_DRY_RUN AIPMS_ALLOW_EMULATOR

  python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

summary = {
    "kind": "android_public_apk_install_check",
    "checked_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "mode": os.environ["mode"],
    "dry_run": os.environ["AIPMS_ANDROID_INSTALL_DRY_RUN"] == "1",
    "allow_emulator": os.environ["AIPMS_ALLOW_EMULATOR"] == "1",
    "apk": {
        "path": os.environ["APK"],
        "sha256": os.environ["APK_SHA256"],
        "size_bytes": int(os.environ["APK_SIZE_BYTES"]),
        "package_name": os.environ["PACKAGE_NAME"],
    },
    "device": {
        "serial": os.environ["device_serial"] or None,
        "wm_size": os.environ["wm_size"] or None,
        "wm_density": os.environ["wm_density"] or None,
        "android_release": os.environ["android_release"] or None,
    },
    "result": {
        "install_status": os.environ["install_status"],
        "launch_status": os.environ["launch_status"],
    },
    "commands": [
        f"adb install -r {os.environ['APK']}",
        f"adb shell pm grant {os.environ['PACKAGE_NAME']} android.permission.RECORD_AUDIO",
        f"adb shell am start -n {os.environ['MAIN_ACTIVITY']}",
    ],
    "next_manual_checks": [
        "Confirm phone-width layout uses a single-column flow.",
        "Confirm tablet-width layout uses a two-column capture/control flow.",
        "Run one login, project selection, automatic project-member distribution check, recording, upload, and status check.",
        "Do not add a manual attendee selection step before recording or upload.",
    ],
}

Path(os.environ["SUMMARY_JSON"]).write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

dry_run_note = (
    "Dry-run mode only validated APK presence, checksum, package name, and the "
    "commands that will be used. A physical device install is still required."
    if summary["dry_run"]
    else "The script completed adb install and app launch commands on the selected device."
)

markdown = "\n".join(
    [
        "# AI-PMS Recorder APK 설치검증 리포트",
        "",
        f"- 생성시각(UTC): `{summary['checked_at']}`",
        f"- 모드: `{summary['mode']}`",
        f"- Dry-run: `{summary['dry_run']}`",
        f"- 패키지명: `{summary['apk']['package_name']}`",
        "",
        "## APK",
        "",
        f"- 경로: `{summary['apk']['path']}`",
        f"- SHA256: `{summary['apk']['sha256']}`",
        f"- 크기(bytes): `{summary['apk']['size_bytes']}`",
        "",
        "## 기기",
        "",
        f"- Serial: `{summary['device']['serial'] or '미연결'}`",
        f"- 화면 크기: `{summary['device']['wm_size'] or '미확인'}`",
        f"- 화면 밀도: `{summary['device']['wm_density'] or '미확인'}`",
        f"- Android 버전: `{summary['device']['android_release'] or '미확인'}`",
        "",
        "## 결과",
        "",
        f"- 설치 상태: `{summary['result']['install_status']}`",
        f"- 실행 상태: `{summary['result']['launch_status']}`",
        f"- 판정: {dry_run_note}",
        "",
        "## 실행 명령",
        "",
        *[f"- `{command}`" for command in summary["commands"]],
        "",
        "## 다음 수동 확인",
        "",
        *[f"- {check}" for check in summary["next_manual_checks"]],
        "",
    ]
) + "\n"

Path(os.environ["SUMMARY_MD"]).write_text(markdown, encoding="utf-8")
direct_report = Path(os.environ["DIRECT_REPORT_MD"])
direct_report.parent.mkdir(parents=True, exist_ok=True)
direct_report.write_text(markdown, encoding="utf-8")
PY
}

if [ "$AIPMS_ANDROID_INSTALL_DRY_RUN" = "1" ]; then
  write_summary "dry_run"
  cat <<EOF
Android public APK install dry-run completed.

APK:
  $APK

SHA256:
  $APK_SHA256

Summary:
  $SUMMARY_JSON

Report:
  $SUMMARY_MD
  $DIRECT_REPORT_MD
EOF
  exit 0
fi

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
  echo "Missing adb command. Install Android platform-tools or set ADB=/path/to/adb." >&2
  exit 1
fi

if [ -n "${ANDROID_SERIAL:-}" ]; then
  device_id="$ANDROID_SERIAL"
else
  if [ "$AIPMS_ALLOW_EMULATOR" = "1" ]; then
    device_ids="$("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
  else
    device_ids="$("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }')"
  fi
  device_count="$(printf '%s\n' "$device_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$device_count" = "0" ]; then
    cat >&2 <<'EOF'
No eligible Android device is connected.

Checklist:
1. Connect the phone or tablet by USB.
2. Enable Developer Options and USB debugging.
3. Accept the RSA debugging prompt.
4. Run: adb devices
5. For emulator testing, set AIPMS_ALLOW_EMULATOR=1.
EOF
    exit 1
  fi
  if [ "$device_count" != "1" ]; then
    echo "Multiple Android devices detected. Set ANDROID_SERIAL to one of:" >&2
    printf '%s\n' "$device_ids" >&2
    exit 1
  fi
  device_id="$device_ids"
fi

"$ADB_BIN" -s "$device_id" install -r "$APK"
"$ADB_BIN" -s "$device_id" shell pm grant "$PACKAGE_NAME" android.permission.RECORD_AUDIO || true
"$ADB_BIN" -s "$device_id" shell am start -n "$MAIN_ACTIVITY"

wm_size="$("$ADB_BIN" -s "$device_id" shell wm size 2>/dev/null | tr -d '\r' || true)"
wm_density="$("$ADB_BIN" -s "$device_id" shell wm density 2>/dev/null | tr -d '\r' || true)"
android_release="$("$ADB_BIN" -s "$device_id" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)"

write_summary "installed" "$device_id" "installed" "$wm_size" "$wm_density" "$android_release" "launched"

cat <<EOF
Installed and launched $PACKAGE_NAME on $device_id.

Summary:
  $SUMMARY_JSON

Report:
  $SUMMARY_MD
  $DIRECT_REPORT_MD
EOF

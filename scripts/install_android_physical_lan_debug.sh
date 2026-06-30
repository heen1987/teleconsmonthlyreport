#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

"$ROOT_DIR/scripts/build_android_lan_debug.sh"

APK="$ROOT_DIR/android_client/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk"

device_ids="$(
  adb devices | awk '
    NR > 1 && $2 == "device" && $1 !~ /^emulator-/ {
      print $1
    }
  '
)"

device_count="$(printf '%s\n' "$device_ids" | sed '/^$/d' | wc -l | tr -d ' ')"

if [ "$device_count" = "0" ]; then
  cat >&2 <<'EOF'
No physical Android device is connected.

Checklist:
1. Connect the Android device by USB.
2. Enable Developer Options and USB debugging on the device.
3. Accept the RSA debugging prompt on the device.
4. Run: adb devices
EOF
  exit 1
fi

if [ "$device_count" != "1" ]; then
  echo "Multiple physical devices detected. Set ANDROID_SERIAL to one of:" >&2
  printf '%s\n' "$device_ids" >&2
  exit 1
fi

device_id="${ANDROID_SERIAL:-$device_ids}"

adb -s "$device_id" install -r "$APK"
adb -s "$device_id" shell pm grant com.aipms android.permission.RECORD_AUDIO || true
adb -s "$device_id" shell am start -n com.aipms/.MainActivity

echo "Installed and launched com.aipms on $device_id"

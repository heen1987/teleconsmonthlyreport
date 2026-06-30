#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

"$ROOT_DIR/scripts/build_android_debug.sh"

APK="$ROOT_DIR/android_client/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk"
adb wait-for-device
adb install -r "$APK"
adb shell pm grant com.aipms android.permission.RECORD_AUDIO || true
adb shell am start -n com.aipms/.MainActivity

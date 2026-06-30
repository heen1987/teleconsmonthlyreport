#!/usr/bin/env bash
set -euo pipefail

AVD_NAME="${AVD_NAME:-ai_pms_api35}"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

exec emulator \
  -avd "$AVD_NAME" \
  -no-snapshot \
  -no-window \
  -no-audio \
  -gpu swiftshader_indirect \
  -netdelay none \
  -netspeed full

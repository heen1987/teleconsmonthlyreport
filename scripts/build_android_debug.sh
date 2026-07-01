#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIPMS_ANDROID_TEMP_BUILD="${AIPMS_ANDROID_TEMP_BUILD:-1}"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

run_gradle() {
  if [[ -x ./gradlew ]]; then
    ./gradlew --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      "$@"
  else
    gradle --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      "$@"
  fi
}

copy_atomic() {
  local source="$1"
  local target="$2"
  local tmp_target="$target.tmp.$$"

  rm -f "$tmp_target"
  cp "$source" "$tmp_target"
  mv -f "$tmp_target" "$target"
}

copy_debug_outputs() {
  local build_dir="$1"
  local output_dir="$ROOT_DIR/android_client/build/outputs/apk/debug"

  mkdir -p "$output_dir"
  copy_atomic \
    "$build_dir/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
    "$output_dir/AiPmsAndroidClient-debug.apk"
  if [ -f "$build_dir/build/outputs/apk/debug/output-metadata.json" ]; then
    copy_atomic "$build_dir/build/outputs/apk/debug/output-metadata.json" \
      "$output_dir/output-metadata.json"
  fi

  echo "APK: $output_dir/AiPmsAndroidClient-debug.apk"
  shasum -a 256 "$output_dir/AiPmsAndroidClient-debug.apk"
}

if [ "$AIPMS_ANDROID_TEMP_BUILD" = "1" ]; then
  TMP_BUILD="${AIPMS_ANDROID_TEMP_DIR:-$(mktemp -d /tmp/ai_pms_android_debug.XXXXXX)}"
  mkdir -p "$TMP_BUILD"
  rsync -a --delete --exclude '.gradle' --exclude 'build' \
    "$ROOT_DIR/android_client/" "$TMP_BUILD/"

  echo "Building Android debug APK in temporary local path"
  echo "Temporary build dir: $TMP_BUILD"

  cd "$TMP_BUILD"
  run_gradle assembleDebug
  copy_debug_outputs "$TMP_BUILD"
else
  cd "$ROOT_DIR/android_client"
  run_gradle assembleDebug
fi

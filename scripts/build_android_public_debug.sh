#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    echo "Missing tunnel log: $log_file" >&2
    return 1
  fi
  grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

PLATFORM_URL="${AIPMS_PLATFORM_BASE_URL:-${AIPMS_PUBLIC_PLATFORM_URL:-$(extract_url platform)}}"
COLLECTION_URL="${AIPMS_COLLECTION_BASE_URL:-${AIPMS_PUBLIC_COLLECTION_URL:-$(extract_url collection)}}"
ANDROID_CLEAN_BUILD="${ANDROID_CLEAN_BUILD:-1}"
AIPMS_ANDROID_TEMP_BUILD="${AIPMS_ANDROID_TEMP_BUILD:-1}"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo "Building responsive Android debug APK for public tunnel access"
echo "Platform API:   $PLATFORM_URL"
echo "Collection API: $COLLECTION_URL"

gradle_tasks=()
if [ "$ANDROID_CLEAN_BUILD" = "1" ]; then
  gradle_tasks+=("clean")
fi
gradle_tasks+=("assembleDebug")

run_gradle() {
  if [[ -x ./gradlew ]]; then
    ./gradlew --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
      -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
      "$@"
  else
    gradle --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
      -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
      "$@"
  fi
}

if [ "$AIPMS_ANDROID_TEMP_BUILD" = "1" ]; then
  BUILD_DIR="${AIPMS_ANDROID_TEMP_DIR:-$(mktemp -d /tmp/ai_pms_android_public.XXXXXX)}"
  mkdir -p "$BUILD_DIR"
  rsync -a --delete --exclude '.gradle' --exclude 'build' \
    "$ROOT_DIR/android_client/" "$BUILD_DIR/"
  echo "Temporary build dir: $BUILD_DIR"
else
  BUILD_DIR="$ROOT_DIR/android_client"
fi

cd "$BUILD_DIR"
run_gradle "${gradle_tasks[@]}"

mkdir -p "$ROOT_DIR/android_client/build/outputs/apk/debug"
cp "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/android_client/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk"
if [ -f "$BUILD_DIR/build/outputs/apk/debug/output-metadata.json" ]; then
  cp "$BUILD_DIR/build/outputs/apk/debug/output-metadata.json" \
    "$ROOT_DIR/android_client/build/outputs/apk/debug/output-metadata.json"
fi

mkdir -p "$ROOT_DIR/artifacts/apk"
cp "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"
cp "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-public-debug.apk"
cp "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AI-PMS-Recorder.apk"

if [ -x "$ROOT_DIR/scripts/publish_android_apk_download.sh" ]; then
  "$ROOT_DIR/scripts/publish_android_apk_download.sh"
fi

echo "APK: $ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"
shasum -a 256 "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"

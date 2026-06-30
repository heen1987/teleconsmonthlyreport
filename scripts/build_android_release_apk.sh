#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
ANDROID_CLEAN_BUILD="${ANDROID_CLEAN_BUILD:-1}"
AIPMS_ANDROID_TEMP_BUILD="${AIPMS_ANDROID_TEMP_BUILD:-1}"

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    echo "Missing tunnel log: $log_file" >&2
    return 1
  fi
  grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

require_env AIPMS_RELEASE_STORE_FILE
require_env AIPMS_RELEASE_STORE_PASSWORD
require_env AIPMS_RELEASE_KEY_ALIAS
require_env AIPMS_RELEASE_KEY_PASSWORD

PLATFORM_URL="${AIPMS_PLATFORM_BASE_URL:-${AIPMS_PUBLIC_PLATFORM_URL:-$(extract_url platform)}}"
COLLECTION_URL="${AIPMS_COLLECTION_BASE_URL:-${AIPMS_PUBLIC_COLLECTION_URL:-$(extract_url collection)}}"

if [ ! -f "$AIPMS_RELEASE_STORE_FILE" ]; then
  echo "Release keystore file does not exist: $AIPMS_RELEASE_STORE_FILE" >&2
  exit 1
fi

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo "Building signed Android release APK"
echo "Platform API:   $PLATFORM_URL"
echo "Collection API: $COLLECTION_URL"
echo "Keystore:       $AIPMS_RELEASE_STORE_FILE"
echo "Key alias:      $AIPMS_RELEASE_KEY_ALIAS"

gradle_tasks=()
if [ "$ANDROID_CLEAN_BUILD" = "1" ]; then
  gradle_tasks+=("clean")
fi
gradle_tasks+=("assembleRelease")

run_gradle() {
  if [[ -x ./gradlew ]]; then
    ./gradlew --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
      -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
      -PaipmsReleaseStoreFile="$AIPMS_RELEASE_STORE_FILE" \
      -PaipmsReleaseStorePassword="$AIPMS_RELEASE_STORE_PASSWORD" \
      -PaipmsReleaseKeyAlias="$AIPMS_RELEASE_KEY_ALIAS" \
      -PaipmsReleaseKeyPassword="$AIPMS_RELEASE_KEY_PASSWORD" \
      "$@"
  else
    gradle --no-daemon --console=plain --max-workers=1 \
      -Dorg.gradle.vfs.watch=false \
      -Dkotlin.incremental=false \
      -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
      -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
      -PaipmsReleaseStoreFile="$AIPMS_RELEASE_STORE_FILE" \
      -PaipmsReleaseStorePassword="$AIPMS_RELEASE_STORE_PASSWORD" \
      -PaipmsReleaseKeyAlias="$AIPMS_RELEASE_KEY_ALIAS" \
      -PaipmsReleaseKeyPassword="$AIPMS_RELEASE_KEY_PASSWORD" \
      "$@"
  fi
}

if [ "$AIPMS_ANDROID_TEMP_BUILD" = "1" ]; then
  BUILD_DIR="${AIPMS_ANDROID_TEMP_DIR:-$(mktemp -d /tmp/ai_pms_android_release.XXXXXX)}"
  mkdir -p "$BUILD_DIR"
  rsync -a --delete --exclude '.gradle' --exclude 'build' \
    "$ROOT_DIR/android_client/" "$BUILD_DIR/"
  echo "Temporary build dir: $BUILD_DIR"
else
  BUILD_DIR="$ROOT_DIR/android_client"
fi

cd "$BUILD_DIR"
run_gradle "${gradle_tasks[@]}"

release_apk="$(find "$BUILD_DIR/build/outputs/apk/release" -maxdepth 1 -name '*.apk' | head -1)"
if [ -z "$release_apk" ]; then
  echo "Release APK was not produced." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/android_client/build/outputs/apk/release"
cp "$release_apk" "$ROOT_DIR/android_client/build/outputs/apk/release/$(basename "$release_apk")"

mkdir -p "$ROOT_DIR/artifacts/apk"
output_apk="$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-release.apk"
cp "$release_apk" "$output_apk"

if command -v apksigner >/dev/null 2>&1; then
  apksigner verify --verbose "$output_apk"
fi

echo "APK: $output_apk"
shasum -a 256 "$output_apk"

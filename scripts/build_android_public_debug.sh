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
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

ANDROID_CLEAN_BUILD="${ANDROID_CLEAN_BUILD:-1}"
AIPMS_ANDROID_TEMP_BUILD="${AIPMS_ANDROID_TEMP_BUILD:-1}"

PLATFORM_URL="${AIPMS_PLATFORM_BASE_URL:-${AIPMS_PUBLIC_PLATFORM_URL:-${AIPMS_PLATFORM_API_URL:-}}}"
COLLECTION_URL="${AIPMS_COLLECTION_BASE_URL:-${AIPMS_PUBLIC_COLLECTION_URL:-}}"
if [ -z "$COLLECTION_URL" ]; then
  COLLECTION_URL="$(extract_url collection || true)"
fi

require_platform_server_url() {
  if [ -z "$PLATFORM_URL" ]; then
    cat >&2 <<'EOF'
Platform server URL is required for public Android builds.

Set one of:
  AIPMS_PLATFORM_BASE_URL=https://<platform-server-url>
  AIPMS_PUBLIC_PLATFORM_URL=https://<platform-server-url>
  AIPMS_PLATFORM_API_URL=https://<platform-server-url>

Do not build the public APK against a LAN IP or this PC.
EOF
    exit 2
  fi

  case "$PLATFORM_URL" in
    http://127.*|https://127.*|http://localhost*|https://localhost*|\
    http://10.*|https://10.*|http://192.168.*|https://192.168.*|\
    http://172.1[6-9].*|https://172.1[6-9].*|http://172.2[0-9].*|https://172.2[0-9].*|\
    http://172.3[0-1].*|https://172.3[0-1].*)
      cat >&2 <<EOF
Platform URL must point to the Platform server, not a local/LAN IP:
  current: $PLATFORM_URL
EOF
      exit 2
      ;;
  esac
}

require_collection_url() {
  if [ -z "$COLLECTION_URL" ]; then
    cat >&2 <<'EOF'
Collection public URL is required for public Android builds.

Start the Mac mini Collection/Analysis tunnel first:
  bash scripts/run_collection_analysis_public_tunnel.sh

Or set:
  AIPMS_PUBLIC_COLLECTION_URL=https://<collection-public-url>
EOF
    exit 2
  fi
}

require_platform_server_url
require_collection_url

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

copy_atomic() {
  local source="$1"
  local target="$2"
  local tmp_target="$target.tmp.$$"

  rm -f "$tmp_target"
  cp "$source" "$tmp_target"
  mv -f "$tmp_target" "$target"
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
copy_atomic "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/android_client/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk"
if [ -f "$BUILD_DIR/build/outputs/apk/debug/output-metadata.json" ]; then
  copy_atomic "$BUILD_DIR/build/outputs/apk/debug/output-metadata.json" \
    "$ROOT_DIR/android_client/build/outputs/apk/debug/output-metadata.json"
fi

mkdir -p "$ROOT_DIR/artifacts/apk"
copy_atomic "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"
copy_atomic "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-public-debug.apk"
copy_atomic "$BUILD_DIR/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk" \
  "$ROOT_DIR/artifacts/apk/AI-PMS-Recorder.apk"

if [ -x "$ROOT_DIR/scripts/publish_android_apk_download.sh" ]; then
  "$ROOT_DIR/scripts/publish_android_apk_download.sh"
fi

echo "APK: $ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"
shasum -a 256 "$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk"

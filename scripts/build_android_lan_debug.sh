#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LAN_IP="${LAN_IP:-}"
if [ -z "$LAN_IP" ]; then
  for iface in en1 en0; do
    if ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"; then
      if [ -n "$ip" ]; then
        LAN_IP="$ip"
        break
      fi
    fi
  done
fi
if [ -z "$LAN_IP" ]; then
  LAN_IP="$(ifconfig | awk '/inet / && $2 !~ /^127\./ { print $2; exit }')"
fi
if [ -z "$LAN_IP" ]; then
  echo "LAN IP not found. Set LAN_IP manually." >&2
  exit 1
fi

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="/opt/homebrew/opt/openjdk@21/bin:/opt/homebrew/opt/gradle@8/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

cd "$ROOT_DIR/android_client"

PLATFORM_URL="${AIPMS_PLATFORM_BASE_URL:-http://$LAN_IP:8000}"
COLLECTION_URL="${AIPMS_COLLECTION_BASE_URL:-http://$LAN_IP:8200}"

echo "Building Android debug APK for physical-device LAN access"
echo "Platform API:   $PLATFORM_URL"
echo "Collection API: $COLLECTION_URL"

if [[ -x ./gradlew ]]; then
  ./gradlew --no-daemon --console=plain --max-workers=1 -Dorg.gradle.vfs.watch=false \
    -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
    -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
    assembleDebug
else
  gradle --no-daemon --console=plain --max-workers=1 -Dorg.gradle.vfs.watch=false \
    -PaipmsPlatformBaseUrl="$PLATFORM_URL" \
    -PaipmsCollectionBaseUrl="$COLLECTION_URL" \
    assembleDebug
fi

echo "APK: $ROOT_DIR/android_client/build/outputs/apk/debug/AiPmsAndroidClient-debug.apk"

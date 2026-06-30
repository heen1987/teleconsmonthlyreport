#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}"
PREPARE_LOG="$TMP_DIR/aipms-release-signing-prepare.log"
MISSING_ENV_LOG="$TMP_DIR/aipms-release-missing-env.log"

cd "$ROOT_DIR"

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing file: $file" >&2
    exit 1
  fi
}

require_text() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "missing $label in $file: $pattern" >&2
    exit 1
  fi
}

echo "Checking Android release signing readiness"
bash scripts/prepare_android_release_signing.sh >"$PREPARE_LOG"

require_file "runtime/android_release_signing/release-signing.env.example"
require_file "runtime/android_release_signing/release-signing-readiness.md"
require_file "../배포_APK/릴리즈서명_준비상태.md"

require_text "runtime/android_release_signing/release-signing.env.example" "AIPMS_RELEASE_STORE_FILE" "release store env"
require_text "runtime/android_release_signing/release-signing.env.example" "<replace-with-strong-store-password>" "store password placeholder"
require_text "runtime/android_release_signing/release-signing-readiness.md" "Release APK distribution is blocked" "release blocked note"
require_text "../배포_APK/릴리즈서명_준비상태.md" "AiPmsAndroidClient-responsive-release.apk" "direct release output note"
require_text "scripts/build_android_release_apk.sh" "AIPMS_ANDROID_TEMP_BUILD" "release temp build mode"
require_text "scripts/build_android_release_apk.sh" "/tmp/ai_pms_android_release" "release temp build path"

if (
  unset AIPMS_RELEASE_STORE_FILE
  unset AIPMS_RELEASE_STORE_PASSWORD
  unset AIPMS_RELEASE_KEY_ALIAS
  unset AIPMS_RELEASE_KEY_PASSWORD
  export AIPMS_PLATFORM_BASE_URL="https://platform.example.invalid"
  export AIPMS_COLLECTION_BASE_URL="https://collection.example.invalid"
  bash scripts/build_android_release_apk.sh
) >"$MISSING_ENV_LOG" 2>&1; then
  echo "release build must fail when signing env is missing" >&2
  exit 1
fi

require_text "$MISSING_ENV_LOG" "Missing required env: AIPMS_RELEASE_STORE_FILE" "missing signing env failure"

echo "Android release signing readiness smoke passed"

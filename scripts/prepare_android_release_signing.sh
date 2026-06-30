#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${AIPMS_ANDROID_RELEASE_OUT_DIR:-$ROOT_DIR/runtime/android_release_signing}"
ENV_EXAMPLE="$OUT_DIR/release-signing.env.example"
READINESS_MD="$OUT_DIR/release-signing-readiness.md"
DIRECT_APK_DIR="${DIRECT_APK_DIR:-$ROOT_DIR/../배포_APK}"
DIRECT_READINESS_MD="$DIRECT_APK_DIR/릴리즈서명_준비상태.md"

mkdir -p "$OUT_DIR" "$DIRECT_APK_DIR"

cat > "$ENV_EXAMPLE" <<EOF
# Source this file after replacing every placeholder.
export AIPMS_RELEASE_STORE_FILE="$OUT_DIR/aipms-release.jks"
export AIPMS_RELEASE_STORE_PASSWORD="<replace-with-strong-store-password>"
export AIPMS_RELEASE_KEY_ALIAS="aipms-release"
export AIPMS_RELEASE_KEY_PASSWORD="<replace-with-strong-key-password>"
EOF

cat > "$READINESS_MD" <<EOF
# Android Release Signing Readiness

Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Current Status

- Debug APK handoff is available for short-term tester review.
- Release APK distribution is blocked until real keystore credentials are
  provided through environment variables.
- Real passwords and keystore files must not be committed to the repository or
  shared Drive documents.

## Required Environment

\`\`\`bash
export AIPMS_RELEASE_STORE_FILE="/absolute/path/to/aipms-release.jks"
export AIPMS_RELEASE_STORE_PASSWORD="<strong-store-password>"
export AIPMS_RELEASE_KEY_ALIAS="aipms-release"
export AIPMS_RELEASE_KEY_PASSWORD="<strong-key-password>"
\`\`\`

## Commands

\`\`\`bash
bash scripts/prepare_android_release_signing.sh
bash scripts/build_android_release_apk.sh
\`\`\`

## Expected Output

\`\`\`text
artifacts/apk/AiPmsAndroidClient-responsive-release.apk
\`\`\`

## Distribution Rule

- Use \`AI-PMS-Recorder.apk\` debug signing only for short-term internal review.
- Use the release APK for long-term external testing and stable app upgrades.
EOF

cp "$READINESS_MD" "$DIRECT_READINESS_MD"

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

if [ "${AIPMS_GENERATE_RELEASE_KEYSTORE:-0}" = "1" ]; then
  if ! command -v keytool >/dev/null 2>&1; then
    echo "Missing required command: keytool" >&2
    exit 1
  fi
  require_env AIPMS_RELEASE_STORE_FILE
  require_env AIPMS_RELEASE_STORE_PASSWORD
  require_env AIPMS_RELEASE_KEY_ALIAS
  require_env AIPMS_RELEASE_KEY_PASSWORD
  if [ -f "$AIPMS_RELEASE_STORE_FILE" ]; then
    echo "Release keystore already exists: $AIPMS_RELEASE_STORE_FILE" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$AIPMS_RELEASE_STORE_FILE")"
  keytool -genkeypair \
    -v \
    -keystore "$AIPMS_RELEASE_STORE_FILE" \
    -storepass "$AIPMS_RELEASE_STORE_PASSWORD" \
    -alias "$AIPMS_RELEASE_KEY_ALIAS" \
    -keypass "$AIPMS_RELEASE_KEY_PASSWORD" \
    -keyalg RSA \
    -keysize 4096 \
    -validity 3650 \
    -dname "CN=AI-PMS, OU=Education, O=AI-PMS, L=Seoul, ST=Seoul, C=KR"
  echo "Release keystore created: $AIPMS_RELEASE_STORE_FILE"
else
  echo "Release signing env template written: $ENV_EXAMPLE"
  echo "Release signing readiness report written: $READINESS_MD"
  echo "Direct handoff readiness report written: $DIRECT_READINESS_MD"
  echo "Set AIPMS_GENERATE_RELEASE_KEYSTORE=1 with real passwords to create a local keystore."
fi

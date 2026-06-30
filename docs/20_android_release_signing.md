# Android Release Signing

Last updated: 2026-06-29

## Purpose

The public APK currently uses debug signing for team review. Long-term
external distribution needs release signing so the same package can be
upgraded predictably on phones and tablets.

## Required Values

Do not commit real passwords or keystores.

```bash
export AIPMS_RELEASE_STORE_FILE="/absolute/path/to/aipms-release.jks"
export AIPMS_RELEASE_STORE_PASSWORD="<strong-store-password>"
export AIPMS_RELEASE_KEY_ALIAS="aipms-release"
export AIPMS_RELEASE_KEY_PASSWORD="<strong-key-password>"
```

Generate an env template:

```bash
bash scripts/prepare_android_release_signing.sh
```

The template is written to:

```text
runtime/android_release_signing/release-signing.env.example
```

The same command also writes readiness reports:

```text
runtime/android_release_signing/release-signing-readiness.md
../배포_APK/릴리즈서명_준비상태.md
```

## Optional Local Keystore Generation

Only run this after choosing real passwords and a secure local path.

```bash
export AIPMS_RELEASE_STORE_FILE="/absolute/path/to/aipms-release.jks"
export AIPMS_RELEASE_STORE_PASSWORD="<strong-store-password>"
export AIPMS_RELEASE_KEY_ALIAS="aipms-release"
export AIPMS_RELEASE_KEY_PASSWORD="<strong-key-password>"
export AIPMS_GENERATE_RELEASE_KEYSTORE=1
bash scripts/prepare_android_release_signing.sh
```

## Build

For fixed-domain external access, use named tunnel URLs:

```bash
export AIPMS_PUBLIC_PLATFORM_URL="https://api.pms.example.com"
export AIPMS_PUBLIC_COLLECTION_URL="https://collection.pms.example.com"
bash scripts/build_android_release_apk.sh
```

The release build uses a temporary local build directory by default so Google
Drive sync does not stall Gradle:

```text
/tmp/ai_pms_android_release.*
```

Output:

```text
artifacts/apk/AiPmsAndroidClient-responsive-release.apk
```

## Verification

The build script runs `apksigner verify --verbose` when `apksigner` is
available on `PATH`, then prints the SHA256 hash.

Readiness smoke:

```bash
bash scripts/smoke_android_release_readiness.sh
```

This verifies that the signing template and readiness reports exist and that a
release build fails fast when the required signing environment variables are
missing.

## Distribution Rule

- Debug APK: short-term team review only.
- Release APK: external review, stable device upgrade path, and final
  portfolio demonstration.
- When fixed Platform/Collection URLs change, rebuild the APK before sharing.

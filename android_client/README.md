# AI-PMS Android Client

This folder contains the first native Android pass for Kim Heeseop's Android
integration scope. It is structured as a single Android application module that
can be opened from Android Studio after JDK/Android SDK installation.

The current Mac mini has the command-line Android build chain installed:

- Homebrew `openjdk@21`
- Homebrew `gradle@8`
- Android command-line tools
- Android SDK Platform 35
- Android SDK Build-Tools 35.0.0
- Gradle wrapper pinned to Gradle 8.13
- Android Emulator 36.6.11
- AVD `ai_pms_api35` using API 35 Google APIs ARM64

Target Android MVP flow:

- A-001 employee-number login
- A-002 project selection
- A-003 meeting title or Meeting ID
- A-004 recording/upload
- A-005 upload/analysis status

Implemented first-pass behavior:

- plain Android `Activity` UI without Compose dependency
- responsive phone/tablet layout in one APK
- single-screen recorder-first UI with no side menu, no tab menu, and no
  explanatory guide cards
- Drive screen-design aligned MEETFLOW visual style: white mobile surface,
  navy headings, teal brand mark, thin bordered cards, and recording waveform
- employee-number login against Platform API
- bearer token persistence and `/users/me` restore
- initial password change before project lookup/upload
- no attendee manual selection before upload
- Android client does not include attendee-save API contracts; recording
  context is fixed by project selection and Meeting ID only
- runtime microphone permission request
- `MediaRecorder` AAC/M4A recording under app cache
- Ktor Android client for Platform and Collection APIs
- upload session creation with size/checksum metadata
- multipart audio upload with `X-Upload-Token`
- analysis job creation
- job polling until `completed`, `failed`, or `cancelled`

APIs used:

- Platform API `POST /users/login`
- Platform API `GET /users/me`
- Platform API `POST /users/password/change`
- Platform API `POST /users/logout`
- Platform API `GET /projects`
- Platform API `GET /projects/{project_id}/detail`
- Collection API `POST /upload-sessions`
- Collection API `POST /upload-sessions/{session_id}/audio-file`
- Collection API `POST /analysis-jobs`
- Collection API `GET /analysis-jobs/{job_id}`

Local emulator defaults:

- Platform API: `http://10.0.2.2:8000`
- Collection API: `http://10.0.2.2:8200`

`10.0.2.2` routes from the Android emulator to the host Mac. On a physical
device, use the Mac mini LAN IP and make sure the backend ports are reachable.
The debug build can inject physical-device LAN defaults through Gradle
properties:

```bash
./gradlew assembleDebug \
  -PaipmsPlatformBaseUrl=http://192.168.219.102:8000 \
  -PaipmsCollectionBaseUrl=http://192.168.219.102:8200
```

Build:

```bash
cd android_client
./gradlew assembleDebug
```

From the repository root, the environment-safe command is:

```bash
bash scripts/build_android_debug.sh
```

Physical-device LAN build:

```bash
bash scripts/smoke_lan_access.sh
bash scripts/build_android_lan_debug.sh
```

Temporary public-tunnel build:

```bash
bash scripts/run_public_tunnels.sh
bash scripts/refresh_public_handoff_bundle.sh
```

The public Web tunnel serves `/run/` as an execution hub for Web, API, APK,
handoff, and verification commands. The same refresh publishes
`/run/execution.json` for machine-readable run paths.

Rebuild the APK during the same refresh when tunnel URLs changed:

```bash
bash scripts/build_android_public_debug.sh
AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh
```

The public build creates `artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk`
with active Platform and Collection tunnel URLs as the app defaults.
It also writes the same installable APK as `artifacts/apk/AI-PMS-Recorder.apk`
for nontechnical testers.
The publish script copies the APK into `web_client/public/downloads/` so the
active Web tunnel can serve `/downloads/`, `AI-PMS-Recorder.apk`, and the
traceable build filename directly. The review package script adds
`/handoff/public-review-package.json` for team verification.
The install guide at `/downloads/install.html` lists phone/tablet layout and
recording/upload/status checks for external device testing.

Install the published public APK on one USB-connected Android device:

```bash
AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh
bash scripts/install_android_public_debug_apk.sh
```

Release-signing preparation:

```bash
bash scripts/prepare_android_release_signing.sh
bash scripts/build_android_release_apk.sh
```

The release build requires `AIPMS_RELEASE_STORE_FILE`,
`AIPMS_RELEASE_STORE_PASSWORD`, `AIPMS_RELEASE_KEY_ALIAS`, and
`AIPMS_RELEASE_KEY_PASSWORD`. See `docs/20_android_release_signing.md`.

Run emulator and install:

```bash
bash scripts/run_android_emulator.sh
bash scripts/install_android_debug.sh
```

Install on one USB-connected physical Android device:

```bash
bash scripts/install_android_physical_lan_debug.sh
```

Verified locally:

```text
BUILD SUCCESSFUL
APK install Success
com.aipms/.MainActivity focused
Project API lookup succeeded
Project-member automatic distribution target lookup succeeded
No Android attendee-save API contract is packaged
Android-uploaded M4A asset -> STT -> LLM -> Platform callback succeeded
```

Current source map:

- `src/main/java/com/aipms/MainActivity.kt`: A-001 to A-005 single-screen recorder flow with Drive screen-design visual styling
- `src/main/java/com/aipms/recording/AndroidAudioRecorder.kt`: microphone recorder
- `src/main/java/com/aipms/client/KtorAiPmsApiClient.kt`: API client
- `src/main/java/com/aipms/client/MeetingUploadRepository.kt`: upload/job orchestration
- `src/main/java/com/aipms/client/AiPmsContracts.kt`: DTO contracts

Remaining device-level work:

- install Android Studio if GUI editing/emulator management is preferred
- run end-to-end recording/upload on a USB-connected physical Android device

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_SOURCE="${APK_SOURCE:-$ROOT_DIR/artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk}"
DOWNLOAD_DIR="$ROOT_DIR/web_client/public/downloads"
DIRECT_APK_DIR="${DIRECT_APK_DIR:-$ROOT_DIR/../배포_APK}"
LOCAL_DOWNLOAD_APK_DIR="${LOCAL_DOWNLOAD_APK_DIR:-$HOME/Downloads/AI-PMS-APK}"
APK_NAME="AiPmsAndroidClient-responsive-public-debug.apk"
APK_ALIAS_NAME="AI-PMS-Recorder.apk"
APK_TARGET="$DOWNLOAD_DIR/$APK_NAME"
APK_ALIAS_TARGET="$DOWNLOAD_DIR/$APK_ALIAS_NAME"
METADATA_TARGET="$DOWNLOAD_DIR/android-apk.json"
INDEX_TARGET="$DOWNLOAD_DIR/index.html"
INSTALL_TARGET="$DOWNLOAD_DIR/install.html"
DIRECT_APK_TARGET="$DIRECT_APK_DIR/$APK_ALIAS_NAME"
DIRECT_SHA_TARGET="$DIRECT_APK_DIR/AI-PMS-Recorder.sha256"
DIRECT_MANIFEST_TARGET="$DIRECT_APK_DIR/apk_manifest.json"
DIRECT_README_TARGET="$DIRECT_APK_DIR/README.md"
LOCAL_DOWNLOAD_APK_TARGET="$LOCAL_DOWNLOAD_APK_DIR/$APK_ALIAS_NAME"

if [ ! -f "$APK_SOURCE" ]; then
  echo "APK not found: $APK_SOURCE" >&2
  echo "Run scripts/build_android_public_debug.sh first." >&2
  exit 1
fi

mkdir -p "$DOWNLOAD_DIR"
cp "$APK_SOURCE" "$APK_TARGET"
cp "$APK_SOURCE" "$APK_ALIAS_TARGET"

SHA256="$(shasum -a 256 "$APK_TARGET" | awk '{ print $1 }')"
SIZE_BYTES="$(wc -c < "$APK_TARGET" | tr -d ' ')"
SIZE_MB="$(awk "BEGIN { printf \"%.1f\", $SIZE_BYTES / 1024 / 1024 }")"
PUBLISHED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$METADATA_TARGET" <<EOF
{
  "app_name": "AI-PMS Recorder",
  "package_name": "com.aipms",
  "apk": "$APK_NAME",
  "apk_alias": "$APK_ALIAS_NAME",
  "sha256": "$SHA256",
  "size_bytes": $SIZE_BYTES,
  "size_mb": "$SIZE_MB",
  "published_at": "$PUBLISHED_AT",
  "layout": "responsive_phone_tablet",
  "signing": "debug_v2"
}
EOF

mkdir -p "$DIRECT_APK_DIR" "$LOCAL_DOWNLOAD_APK_DIR"
cp "$APK_SOURCE" "$DIRECT_APK_TARGET"
cp "$APK_SOURCE" "$LOCAL_DOWNLOAD_APK_TARGET"

cat > "$DIRECT_SHA_TARGET" <<EOF
$SHA256  $APK_ALIAS_NAME
EOF

cat > "$DIRECT_MANIFEST_TARGET" <<EOF
{
  "artifact_type": "android_apk",
  "device_targets": [
    "phone",
    "tablet"
  ],
  "display_name": "AI-PMS Recorder",
  "distribution_type": "direct_apk_handoff",
  "file_name": "$APK_ALIAS_NAME",
  "flow_policy": "project_only_recording_auto_project_member_distribution",
  "handoff_path": "배포_APK/$APK_ALIAS_NAME",
  "minimum_manual_checks": [
    "install APK on Android device",
    "verify Platform API URL",
    "verify Collection API URL",
    "login with employee-number account",
    "select project and confirm automatic project-member distribution target including email",
    "record audio",
    "upload audio",
    "confirm analysis status",
    "confirm result appears in Web review flow"
  ],
  "package_name": "com.aipms",
  "responsive_layout": true,
  "sha256": "$SHA256",
  "size_bytes": $SIZE_BYTES,
  "source_artifact": "ai_pms_bootstrap/artifacts/apk/AI-PMS-Recorder.apk",
  "updated_at": "$PUBLISHED_AT",
  "app_name": "AI-PMS Recorder",
  "apk": "$APK_ALIAS_NAME",
  "published_at": "$PUBLISHED_AT",
  "build_note": "drive_screen_design_recorder_first_project_only_no_attendee_save_contract"
}
EOF

cat > "$DIRECT_README_TARGET" <<EOF
# AI-PMS Recorder APK 설치 안내

## 설치 파일

- 파일명: \`$APK_ALIAS_NAME\`
- 용도: AI-PMS 회의 녹음, 업로드, 분석 상태 확인용 Android 앱
- 대상: 휴대폰/태블릿 공용 반응형 APK
- 형식: Android 설치 패키지 \`.apk\`

이 폴더의 APK는 zip 배포본이 아닙니다. Android에서 직접 설치하는 설치
패키지입니다. APK 내부 포맷은 Android 표준상 zip 컨테이너로 인식될 수 있지만,
사용자에게 제공해야 하는 파일은 \`$APK_ALIAS_NAME\`입니다.

## 설치 전 확인

1. Android 기기에서 APK 파일을 내려받거나 복사합니다.
2. 설치 시 "알 수 없는 앱 설치" 허용이 필요하면 허용합니다.
3. 설치 후 앱을 실행합니다.
4. 첫 화면의 Platform API URL, Collection API URL 값을 현재 서버 주소로 확인합니다.

외부망 테스트는 서버 터널 또는 고정 도메인이 살아 있어야 합니다. 터널 URL이
바뀐 경우 APK를 새 URL로 다시 빌드하거나 앱 첫 화면의 API URL 입력값을 현재
주소로 수정해 테스트합니다.

## 기본 점검 흐름

1. 사번/비밀번호로 로그인합니다.
2. 초기 비밀번호 변경 상태면 새 비밀번호를 설정합니다.
3. 프로젝트를 선택합니다.
4. 프로젝트 구성원 자동 배포 대상과 이메일 미등록 여부를 확인합니다.
5. 회의를 녹음합니다.
6. 업로드를 실행합니다.
7. 분석 Job 상태가 \`completed\` 또는 실패 사유로 표시되는지 확인합니다.
8. Web에서 회의록 검토/승인 화면에 결과가 반영되는지 확인합니다.

앱의 MVP 흐름에서는 참석자를 수동 선택하지 않습니다. 선택한 프로젝트의
참여인원 정보가 승인 회의록 배포 대상 산정 기준입니다.

## 무결성 확인

APK 해시:

\`\`\`text
$SHA256
\`\`\`

macOS에서 확인:

\`\`\`bash
shasum -a 256 $APK_ALIAS_NAME
\`\`\`

출력값이 위 해시와 같으면 현재 제공 APK와 동일한 파일입니다.

## 설치 검증 리포트

설치 전 dry-run 또는 USB 연결 기기 설치 검증은 다음 명령으로 수행합니다.
프로젝트 개발 폴더 \`ai_pms_bootstrap\`에서 실행합니다.

\`\`\`bash
AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh
bash scripts/install_android_public_debug_apk.sh
\`\`\`

검증 결과는 \`설치검증_리포트.md\`에 기록됩니다.
EOF

cat > "$INDEX_TARGET" <<EOF
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AI-PMS Android APK</title>
    <style>
      body {
        margin: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #f3f7fb;
        color: #0b1720;
      }
      main {
        max-width: 760px;
        margin: 0 auto;
        padding: 32px 18px;
      }
      section {
        background: #ffffff;
        border: 1px solid #d9e3ec;
        border-radius: 8px;
        padding: 22px;
      }
      h1 {
        margin: 0 0 10px;
        font-size: 28px;
        line-height: 1.2;
      }
      p {
        margin: 8px 0;
        color: #405465;
        line-height: 1.55;
      }
      a.button {
        display: inline-block;
        margin-top: 18px;
        margin-right: 8px;
        padding: 12px 16px;
        border-radius: 8px;
        background: #1769ff;
        color: #ffffff;
        text-decoration: none;
        font-weight: 700;
      }
      a.button.secondary {
        background: #0f5e72;
      }
      dl {
        display: grid;
        grid-template-columns: 120px 1fr;
        gap: 8px 12px;
        margin: 18px 0 0;
        font-size: 14px;
      }
      dt {
        color: #667789;
      }
      dd {
        margin: 0;
        overflow-wrap: anywhere;
      }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      }
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>AI-PMS Recorder APK</h1>
        <p>휴대폰과 태블릿 화면에 자동 대응하는 Android debug APK입니다.</p>
        <p>Android에서 설치 차단 안내가 나오면 테스트용 APK 설치를 허용해야 합니다.</p>
        <a class="button" href="./$APK_ALIAS_NAME" download>APK 다운로드</a>
        <a class="button secondary" href="/run/">실행 허브</a>
        <a class="button secondary" href="./$APK_NAME" download>개발자용 파일명</a>
        <a class="button secondary" href="./install.html">설치 확인 가이드</a>
        <dl>
          <dt>Package</dt>
          <dd><code>com.aipms</code></dd>
          <dt>Install file</dt>
          <dd><code>$APK_ALIAS_NAME</code></dd>
          <dt>Build file</dt>
          <dd><code>$APK_NAME</code></dd>
          <dt>Size</dt>
          <dd>$SIZE_MB MB</dd>
          <dt>SHA256</dt>
          <dd><code>$SHA256</code></dd>
          <dt>Published</dt>
          <dd>$PUBLISHED_AT</dd>
          <dt>Layout</dt>
          <dd>Phone single-column / Tablet two-column</dd>
        </dl>
      </section>
    </main>
  </body>
</html>
EOF

cat > "$INSTALL_TARGET" <<EOF
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AI-PMS Recorder 설치 확인</title>
    <style>
      body {
        margin: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #f3f7fb;
        color: #0b1720;
      }
      main {
        max-width: 880px;
        margin: 0 auto;
        padding: 32px 18px;
      }
      header,
      section {
        background: #ffffff;
        border: 1px solid #d9e3ec;
        border-radius: 8px;
        padding: 22px;
      }
      header {
        margin-bottom: 14px;
      }
      .grid {
        display: grid;
        gap: 14px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
      h1,
      h2,
      p {
        margin: 0;
      }
      h1 {
        font-size: 28px;
        line-height: 1.2;
      }
      h2 {
        font-size: 18px;
        margin-bottom: 10px;
      }
      p,
      li,
      dd,
      dt {
        color: #405465;
        font-size: 14px;
        line-height: 1.55;
      }
      p {
        margin-top: 8px;
      }
      ol,
      ul {
        margin: 8px 0 0;
        padding-left: 20px;
      }
      a.button {
        display: inline-block;
        margin-top: 18px;
        margin-right: 8px;
        padding: 12px 16px;
        border-radius: 8px;
        background: #1769ff;
        color: #ffffff;
        text-decoration: none;
        font-weight: 700;
      }
      a.button.secondary {
        background: #0f5e72;
      }
      dl {
        display: grid;
        grid-template-columns: 120px 1fr;
        gap: 8px 12px;
        margin: 12px 0 0;
      }
      dt {
        color: #667789;
      }
      dd {
        margin: 0;
        overflow-wrap: anywhere;
      }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      }
      @media (max-width: 760px) {
        .grid {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <h1>AI-PMS Recorder 설치 확인</h1>
        <p>휴대폰과 태블릿에서 같은 APK를 설치한 뒤 녹음, 업로드, 처리상태 확인 흐름을 점검합니다.</p>
        <a class="button" href="./$APK_ALIAS_NAME" download>APK 다운로드</a>
        <a class="button secondary" href="/run/">실행 허브</a>
        <a class="button secondary" href="./$APK_NAME" download>개발자용 파일명</a>
        <a class="button secondary" href="./">다운로드 정보</a>
      </header>

      <div class="grid">
        <section>
          <h2>설치 전 확인</h2>
          <ol>
            <li>테스트 기기에서 외부 APK 설치를 허용합니다.</li>
            <li>기존 <code>com.aipms</code> debug 앱이 있으면 필요 시 삭제합니다.</li>
            <li>네트워크가 현재 public Platform/Collection API에 접근 가능한지 확인합니다.</li>
            <li>설치 후 앱 이름이 <code>AI-PMS Recorder</code>로 보이는지 확인합니다.</li>
          </ol>
        </section>

        <section>
          <h2>APK 정보</h2>
          <dl>
            <dt>Package</dt>
            <dd><code>com.aipms</code></dd>
            <dt>Install file</dt>
            <dd><code>$APK_ALIAS_NAME</code></dd>
            <dt>Layout</dt>
            <dd>Phone single-column / Tablet two-column</dd>
            <dt>Size</dt>
            <dd>$SIZE_MB MB</dd>
            <dt>SHA256</dt>
            <dd><code>$SHA256</code></dd>
          </dl>
        </section>

        <section>
          <h2>휴대폰 확인</h2>
          <ul>
            <li>세로 화면에서 프로젝트 선택, 자동 배포 대상 확인, 녹음 컨트롤이 한 컬럼 흐름으로 보이는지 확인합니다.</li>
            <li>긴 프로젝트명과 상태 문구가 버튼이나 카드 밖으로 넘치지 않는지 확인합니다.</li>
            <li>녹음 시작, 중지, 업로드 버튼이 엄지 조작 범위에서 접근 가능한지 확인합니다.</li>
          </ul>
        </section>

        <section>
          <h2>태블릿 확인</h2>
          <ul>
            <li>600dp 이상 화면에서 프로젝트 선택/자동 배포 대상 영역과 녹음/상태 영역이 두 컬럼으로 나뉘는지 확인합니다.</li>
            <li>가로/세로 전환 후에도 버튼, 상태, 목록이 겹치지 않는지 확인합니다.</li>
            <li>회의 상태 확인 영역이 업로드 완료 후에도 안정적으로 유지되는지 확인합니다.</li>
          </ul>
        </section>
      </div>

      <section style="margin-top: 14px">
        <h2>기능 흐름 확인</h2>
        <ol>
          <li>사번으로 로그인하고 필요 시 초기 비밀번호를 변경합니다.</li>
          <li>프로젝트를 선택하고 프로젝트 구성원이 자동 배포 대상임을 확인합니다.</li>
          <li>짧은 테스트 음성을 녹음한 뒤 업로드합니다.</li>
          <li>Collection job이 생성되고 처리상태가 조회되는지 확인합니다.</li>
          <li>Web 콘솔에서 해당 회의가 검토 대상으로 이어지는지 확인합니다.</li>
        </ol>
      </section>
    </main>
  </body>
</html>
EOF

cat <<EOF
Published Android APK download assets:
  $APK_TARGET
  $APK_ALIAS_TARGET
  $DIRECT_APK_TARGET
  $LOCAL_DOWNLOAD_APK_TARGET
  $DIRECT_README_TARGET
  $INDEX_TARGET
  $INSTALL_TARGET
  $METADATA_TARGET
  $DIRECT_SHA_TARGET
  $DIRECT_MANIFEST_TARGET

Download path:
  /downloads/$APK_NAME
  /downloads/$APK_ALIAS_NAME

Index path:
  /downloads/

Install guide path:
  /downloads/install.html

SHA256:
  $SHA256
EOF

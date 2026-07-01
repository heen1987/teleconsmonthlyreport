#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
HANDOFF_DIR="$ROOT_DIR/web_client/public/handoff"
APK_METADATA_PATH="$ROOT_DIR/web_client/public/downloads/android-apk.json"
REQUIREMENTS_METADATA_PATH="$ROOT_DIR/web_client/public/requirements/requirements.json"
PACKAGE_PATH="$HANDOFF_DIR/public-review-package.json"
RESPONSE_TEMPLATE_PATH="$HANDOFF_DIR/review-response-template.md"

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    return 1
  fi
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

require_url() {
  local label="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Missing public $label URL." >&2
    exit 1
  fi
}

WEB_URL="${AIPMS_PUBLIC_WEB_URL:-$(extract_url web || true)}"
PLATFORM_URL="${AIPMS_PUBLIC_PLATFORM_URL:-${AIPMS_PLATFORM_API_URL:-${AIPMS_PLATFORM_URL:-}}}"
COLLECTION_URL="${AIPMS_PUBLIC_COLLECTION_URL:-$(extract_url collection || true)}"
ANALYSIS_URL="${AIPMS_PUBLIC_ANALYSIS_URL:-$COLLECTION_URL}"

require_url "Web" "$WEB_URL"
require_url "Platform" "$PLATFORM_URL"
require_url "Collection" "$COLLECTION_URL"
case "$PLATFORM_URL" in
  http://127.*|https://127.*|http://localhost*|https://localhost*|\
  http://10.*|https://10.*|http://192.168.*|https://192.168.*|\
  http://172.1[6-9].*|https://172.1[6-9].*|http://172.2[0-9].*|https://172.2[0-9].*|\
  http://172.3[0-1].*|https://172.3[0-1].*)
    echo "Platform URL must be the Platform server URL, not a local/LAN IP: $PLATFORM_URL" >&2
    exit 2
    ;;
esac

if [ ! -f "$APK_METADATA_PATH" ]; then
  echo "APK metadata not found: $APK_METADATA_PATH" >&2
  echo "Run scripts/publish_android_apk_download.sh first." >&2
  exit 1
fi

"$ROOT_DIR/scripts/publish_requirements_documents.sh" >/tmp/aipms-requirements-publish.log

if [ ! -f "$REQUIREMENTS_METADATA_PATH" ]; then
  echo "Requirements metadata not found: $REQUIREMENTS_METADATA_PATH" >&2
  exit 1
fi

mkdir -p "$HANDOFF_DIR"

export WEB_URL PLATFORM_URL COLLECTION_URL ANALYSIS_URL APK_METADATA_PATH REQUIREMENTS_METADATA_PATH PACKAGE_PATH RESPONSE_TEMPLATE_PATH

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

web_url = os.environ["WEB_URL"].rstrip("/")
platform_url = os.environ["PLATFORM_URL"].rstrip("/")
collection_url = os.environ["COLLECTION_URL"].rstrip("/")
analysis_url = os.environ["ANALYSIS_URL"].rstrip("/")
apk_metadata_path = Path(os.environ["APK_METADATA_PATH"])
requirements_metadata_path = Path(os.environ["REQUIREMENTS_METADATA_PATH"])
package_path = Path(os.environ["PACKAGE_PATH"])
response_template_path = Path(os.environ["RESPONSE_TEMPLATE_PATH"])

apk_metadata = json.loads(apk_metadata_path.read_text(encoding="utf-8"))
requirements_metadata = json.loads(requirements_metadata_path.read_text(encoding="utf-8"))
apk_name = apk_metadata["apk"]
apk_alias = apk_metadata.get("apk_alias", apk_name)
requirements_docx = requirements_metadata["public_files"]["docx"]["file_name"]
requirements_md = requirements_metadata["public_files"]["markdown"]["file_name"]

review_package = {
    "kind": "public_review_package",
    "project": "AI-PMS",
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "public_urls": {
        "run_hub": f"{web_url}/run/",
        "web_console": web_url,
        "handoff_page": f"{web_url}/handoff/",
        "review_package_json": f"{web_url}/handoff/public-review-package.json",
        "review_response_template": f"{web_url}/handoff/review-response-template.md",
        "apk_download_page": f"{web_url}/downloads/",
        "apk_file": f"{web_url}/downloads/{apk_alias}",
        "apk_build_file": f"{web_url}/downloads/{apk_name}",
        "apk_install_guide": f"{web_url}/downloads/install.html",
        "requirements_docx": f"{web_url}/requirements/{requirements_docx}",
        "requirements_markdown": f"{web_url}/requirements/{requirements_md}",
        "requirements_manifest": f"{web_url}/requirements/requirements.json",
        "platform_docs": f"{platform_url}/docs",
        "collection_docs": f"{collection_url}/docs",
        "analysis_docs": f"{analysis_url}/docs",
    },
    "android_apk": {
        "app_name": apk_metadata["app_name"],
        "package_name": apk_metadata["package_name"],
        "download_url": f"{web_url}/downloads/{apk_alias}",
        "build_file_download_url": f"{web_url}/downloads/{apk_name}",
        "metadata_url": f"{web_url}/downloads/android-apk.json",
        "install_guide_url": f"{web_url}/downloads/install.html",
        "file_name": apk_name,
        "alias_file_name": apk_alias,
        "sha256": apk_metadata["sha256"],
        "size_bytes": apk_metadata["size_bytes"],
        "layout": apk_metadata["layout"],
        "signing": apk_metadata["signing"],
    },
    "requirements": {
        "title": requirements_metadata["title"],
        "version": requirements_metadata["version"],
        "docx_url": f"{web_url}/requirements/{requirements_docx}",
        "markdown_url": f"{web_url}/requirements/{requirements_md}",
        "manifest_url": f"{web_url}/requirements/requirements.json",
        "docx_sha256": requirements_metadata["public_files"]["docx"]["sha256"],
        "markdown_sha256": requirements_metadata["public_files"]["markdown"]["sha256"],
        "scope_controls": requirements_metadata["scope_controls"],
    },
    "response_template": {
        "url": f"{web_url}/handoff/review-response-template.md",
        "required_result_values": ["승인 가능", "수정 필요", "질문", "미검증"],
        "required_sections": ["검토 결과", "확인 항목", "수정 요청", "질문", "미검증 항목"],
    },
    "response_collection": {
        "command": "bash scripts/collect_public_review_responses.sh",
        "inbox_dir": "runtime/review_responses/inbox",
        "summary_json": "runtime/review_responses/latest_summary.json",
        "summary_markdown": "runtime/review_responses/latest_summary.md",
    },
    "review_scopes": [
        {
            "owner": "김희섭",
            "scope": "Android, Web, Mac mini Analysis, external access",
            "check_items": [
                "Android phone/tablet responsive layout and installation",
                "recording, automatic project-member distribution target, upload, and job status flow",
                "Web review, approval, distribution, risk/resource/operations visualization",
                "Mac mini worker STT/LLM completion and JSON validation",
                "temporary public tunnel and APK download handoff",
            ],
        },
        {
            "owner": "김강현",
            "scope": "Collection API",
            "check_items": [
                "upload session and audio asset validation",
                "analysis job create, claim, heartbeat, complete/fail, retry states",
                "callback payload and signature boundary with Platform API",
                "Android and worker API contract compatibility",
            ],
        },
        {
            "owner": "박주연",
            "scope": "Platform API",
            "check_items": [
                "employee-number auth, account state, and admin user management",
                "project, meeting, minutes review, approval, distribution workflow",
                "PMS reflection into tasks, decisions, resources, costs, risks, knowledge",
                "email delivery, ERP handoff, retry queue, and audit boundaries",
            ],
        },
    ],
    "verification": {
        "refresh_command": "bash scripts/refresh_public_handoff_bundle.sh",
        "refresh_with_apk_rebuild": "AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh",
        "publish_order": [
            "bash scripts/run_public_tunnels.sh",
            "bash scripts/print_public_urls.sh",
            "bash scripts/build_android_public_debug.sh",
            "bash scripts/publish_android_apk_download.sh",
            "bash scripts/publish_public_review_package.sh",
            "bash scripts/publish_public_execution_hub.sh",
            "bash scripts/smoke_public_access.sh",
        ],
        "smoke_expected": {
            "web": 200,
            "run": 200,
            "run_static": 200,
            "run_json": 200,
            "downloads": 200,
            "install_guide": 200,
            "handoff": 200,
            "review_package": 200,
            "response_template": 200,
            "requirements_manifest": 200,
            "requirements_markdown": 200,
            "requirements_docx": 200,
            "apk": 200,
            "apk_alias": 200,
            "platform": 200,
            "collection": 200,
            "analysis": 200,
            "cors": 200,
        },
    },
    "known_limits": [
        "Cloudflare quick tunnel URLs can change when the Mac mini or tunnel session restarts.",
        "The current public APK is debug signed; use release signing before long-term external distribution.",
        "Reviewer feedback should be reconciled into requirements, screen/API mapping, and backlog documents.",
    ],
}

package_path.write_text(
    json.dumps(review_package, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

response_template = f"""# AI-PMS 파트별 검토 회신 템플릿

검토자는 본인 담당 범위만 채우고, 모르는 항목은 `미검증`으로 남깁니다.

## 기본 정보

- 검토자:
- 담당 범위: 김희섭 / 김강현 / 박주연
- 검토일:
- 기준 URL: {web_url}/handoff/
- 검토 패키지: {web_url}/handoff/public-review-package.json
- 요구사항정의서: {web_url}/requirements/{requirements_docx}
- 제출 파일명: review-response-<name>.md
- 로컬 수집 경로: runtime/review_responses/inbox/

## 검토 결과

- 결과: 승인 가능 / 수정 필요 / 질문 / 미검증
- 한 줄 요약:

## 확인 항목

| 항목 | 결과 | 근거/메모 |
|---|---|---|
| API 계약 또는 화면 흐름이 담당 범위와 맞는가 |  |  |
| 데이터 상태 전이와 예외 처리가 충분한가 |  |  |
| 테스트 또는 smoke 근거가 확인되는가 |  |  |
| 다른 파트와의 경계가 명확한가 |  |  |
| 문서와 구현이 같은 내용을 말하는가 |  |  |

## 수정 요청

| 우선순위 | 위치/API/화면 | 요청 내용 | 이유 |
|---|---|---|---|
| P1/P2/P3 |  |  |  |

## 질문

| 질문 | 필요한 결정 | 담당 후보 |
|---|---|---|
|  |  |  |

## 미검증 항목

-

## 최종 코멘트

-
"""

response_template_path.write_text(response_template, encoding="utf-8")
PY

cat <<EOF
Published public review package:
  $PACKAGE_PATH
  $RESPONSE_TEMPLATE_PATH

Public path:
  /handoff/public-review-package.json
  /handoff/review-response-template.md
EOF

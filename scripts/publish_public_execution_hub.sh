#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"
RUN_DIR="$ROOT_DIR/web_client/public/run"
APK_METADATA_PATH="$ROOT_DIR/web_client/public/downloads/android-apk.json"
REQUIREMENTS_METADATA_PATH="$ROOT_DIR/web_client/public/requirements/requirements.json"
EXECUTION_JSON_PATH="$RUN_DIR/execution.json"
INDEX_PATH="$RUN_DIR/index.html"

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
    echo "Missing public $label URL. Run scripts/run_public_tunnels.sh first." >&2
    exit 1
  fi
}

WEB_URL="${AIPMS_PUBLIC_WEB_URL:-$(extract_url web || true)}"
PLATFORM_URL="${AIPMS_PUBLIC_PLATFORM_URL:-$(extract_url platform || true)}"
COLLECTION_URL="${AIPMS_PUBLIC_COLLECTION_URL:-$(extract_url collection || true)}"
ANALYSIS_URL="${AIPMS_PUBLIC_ANALYSIS_URL:-$(extract_url analysis || true)}"

require_url "Web" "$WEB_URL"
require_url "Platform" "$PLATFORM_URL"
require_url "Collection" "$COLLECTION_URL"
require_url "Analysis" "$ANALYSIS_URL"

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

mkdir -p "$RUN_DIR"

export WEB_URL PLATFORM_URL COLLECTION_URL ANALYSIS_URL APK_METADATA_PATH REQUIREMENTS_METADATA_PATH EXECUTION_JSON_PATH INDEX_PATH

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import html
import json
import os
from pathlib import Path

web_url = os.environ["WEB_URL"].rstrip("/")
platform_url = os.environ["PLATFORM_URL"].rstrip("/")
collection_url = os.environ["COLLECTION_URL"].rstrip("/")
analysis_url = os.environ["ANALYSIS_URL"].rstrip("/")
apk_metadata_path = Path(os.environ["APK_METADATA_PATH"])
requirements_metadata_path = Path(os.environ["REQUIREMENTS_METADATA_PATH"])
execution_json_path = Path(os.environ["EXECUTION_JSON_PATH"])
index_path = Path(os.environ["INDEX_PATH"])

apk_metadata = json.loads(apk_metadata_path.read_text(encoding="utf-8"))
requirements_metadata = json.loads(requirements_metadata_path.read_text(encoding="utf-8"))
apk_name = apk_metadata["apk"]
apk_alias = apk_metadata.get("apk_alias", apk_name)
requirements_docx = requirements_metadata["public_files"]["docx"]["file_name"]
requirements_md = requirements_metadata["public_files"]["markdown"]["file_name"]
generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

execution = {
    "kind": "public_execution_hub",
    "project": "AI-PMS",
    "generated_at": generated_at,
    "public_urls": {
        "run_hub": f"{web_url}/run/",
        "web_console": web_url,
        "apk_download_page": f"{web_url}/downloads/",
        "apk_file": f"{web_url}/downloads/{apk_alias}",
        "apk_build_file": f"{web_url}/downloads/{apk_name}",
        "apk_install_guide": f"{web_url}/downloads/install.html",
        "handoff_page": f"{web_url}/handoff/",
        "review_package_json": f"{web_url}/handoff/public-review-package.json",
        "requirements_docx": f"{web_url}/requirements/{requirements_docx}",
        "requirements_markdown": f"{web_url}/requirements/{requirements_md}",
        "requirements_manifest": f"{web_url}/requirements/requirements.json",
        "platform_health": f"{platform_url}/health",
        "platform_docs": f"{platform_url}/docs",
        "collection_health": f"{collection_url}/health",
        "collection_docs": f"{collection_url}/docs",
        "analysis_health": f"{analysis_url}/health",
        "analysis_docs": f"{analysis_url}/docs",
    },
    "local_urls": {
        "web_client": "http://127.0.0.1:3000",
        "platform_api": "http://127.0.0.1:8000",
        "collection_api": "http://127.0.0.1:8200",
        "analysis_server": "http://127.0.0.1:8100",
    },
    "android_apk": {
        "app_name": apk_metadata["app_name"],
        "package_name": apk_metadata["package_name"],
        "file_name": apk_name,
        "alias_file_name": apk_alias,
        "sha256": apk_metadata["sha256"],
        "size_bytes": apk_metadata["size_bytes"],
        "size_mb": apk_metadata["size_mb"],
        "layout": apk_metadata["layout"],
        "signing": apk_metadata["signing"],
        "published_at": apk_metadata["published_at"],
    },
    "requirements": {
        "title": requirements_metadata["title"],
        "version": requirements_metadata["version"],
        "docx_file_name": requirements_docx,
        "markdown_file_name": requirements_md,
        "docx_sha256": requirements_metadata["public_files"]["docx"]["sha256"],
        "markdown_sha256": requirements_metadata["public_files"]["markdown"]["sha256"],
        "scope_controls": requirements_metadata["scope_controls"],
        "published_at": requirements_metadata["published_at"],
    },
    "execution_commands": [
        {
            "name": "local_base_services",
            "label": "로컬 API 서버",
            "commands": [
                "bash scripts/run_postgres.sh",
                "bash scripts/run_collection_api.sh",
                "bash scripts/run_analysis_server.sh",
                "bash scripts/run_analysis_worker_loop.sh",
                "bash scripts/run_platform_backend.sh",
            ],
        },
        {
            "name": "local_web",
            "label": "로컬 React Web",
            "commands": [
                "cd web_client",
                "VITE_API_BASE=http://127.0.0.1:8000 npm run dev -- --host 127.0.0.1 --port 3000",
            ],
        },
        {
            "name": "public_access",
            "label": "외부 접속 공개",
            "commands": [
                "bash scripts/run_public_tunnels.sh",
                "AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh",
            ],
        },
        {
            "name": "android_apk",
            "label": "Android APK",
            "commands": [
                "bash scripts/build_android_public_debug.sh",
                "bash scripts/install_android_public_debug_apk.sh",
            ],
        },
    ],
    "minimum_checks": [
        "Web console loads from the public URL.",
        "APK download URL returns a file larger than 1 MB.",
        "Phone-width Android device shows single-column layout.",
        "Tablet-width Android device shows two-column layout.",
        "Platform, Collection, and Analysis health endpoints return 200.",
    ],
}

execution_json_path.write_text(
    json.dumps(execution, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

index_html = f"""<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AI-PMS</title>
    <style>
      :root {{
        color: #0b1720;
        background: #f3f7fb;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }}
      * {{
        box-sizing: border-box;
      }}
      body {{
        margin: 0;
      }}
      header {{
        background: linear-gradient(135deg, #071827 0%, #0d2b45 58%, #0f5e72 100%);
        color: #ffffff;
        padding: 30px 18px;
      }}
      .inner {{
        margin: 0 auto;
        max-width: 1180px;
      }}
      h1,
      h2,
      h3,
      p {{
        margin: 0;
      }}
      h1 {{
        font-size: clamp(28px, 4vw, 44px);
        line-height: 1.12;
      }}
      main {{
        display: grid;
        gap: 18px;
        margin: 0 auto;
        max-width: 1180px;
        padding: 22px 18px 38px;
      }}
      section,
      article {{
        background: #ffffff;
        border: 1px solid #d9e3ec;
        border-radius: 8px;
        padding: 18px;
      }}
      h2 {{
        font-size: 20px;
        margin-bottom: 12px;
      }}
      h3 {{
        font-size: 16px;
      }}
      dd,
      dt,
      a {{
        font-size: 14px;
      }}
      dd,
      dt {{
        color: #405465;
        line-height: 1.55;
      }}
      .actions,
      .link-grid {{
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
      }}
      .actions {{
        margin-top: 18px;
      }}
      a.button,
      .link-grid a {{
        align-items: center;
        background: #1769ff;
        border-radius: 8px;
        color: #ffffff;
        display: inline-flex;
        font-weight: 800;
        min-height: 40px;
        padding: 0 14px;
        text-decoration: none;
      }}
      a.button.secondary,
      .link-grid a.secondary {{
        background: #27384a;
      }}
      dl {{
        display: grid;
        gap: 8px 12px;
        grid-template-columns: 130px 1fr;
        margin: 0;
      }}
      dt {{
        color: #667789;
      }}
      dd {{
        margin: 0;
        overflow-wrap: anywhere;
      }}
      .flow {{
        display: grid;
        gap: 8px;
        grid-template-columns: repeat(5, minmax(0, 1fr));
      }}
      .flow div {{
        background: #eef7fa;
        border: 1px solid #caeaf2;
        border-radius: 8px;
        color: #0a4960;
        font-size: 13px;
        font-weight: 800;
        min-height: 72px;
        padding: 12px;
      }}
      @media (max-width: 820px) {{
        .run-grid,
        .flow,
        dl {{
          grid-template-columns: 1fr;
        }}
      }}
    </style>
  </head>
  <body>
    <header>
      <div class="inner">
        <h1>MEETFLOW</h1>
        <div class="actions">
          <a class="button" href="{html.escape(web_url)}">Web 콘솔</a>
          <a class="button" href="{html.escape(web_url)}/downloads/">APK 다운로드</a>
        </div>
      </div>
    </header>
    <main>
      <section>
        <h2>전체 처리 흐름</h2>
        <div class="flow">
          <div>앱<br />녹음</div>
          <div>업로드<br />상태 확인</div>
          <div>회의록<br />검토</div>
          <div>승인<br />배포</div>
          <div>업무<br />반영</div>
        </div>
      </section>

      <section>
        <h2>바로 열기</h2>
        <div class="link-grid">
          <a href="{html.escape(web_url)}">Web 콘솔</a>
          <a href="{html.escape(web_url)}/downloads/">APK 다운로드</a>
        </div>
      </section>

      <section>
        <h2>APK 정보</h2>
        <dl>
          <dt>App</dt>
          <dd>{html.escape(apk_metadata["app_name"])}</dd>
          <dt>File</dt>
          <dd><a href="{html.escape(web_url)}/downloads/{html.escape(apk_alias)}">{html.escape(apk_alias)}</a></dd>
          <dt>Size</dt>
          <dd>{html.escape(str(apk_metadata["size_mb"]))} MB</dd>
          <dt>Layout</dt>
          <dd>휴대폰 / 태블릿</dd>
          <dt>Published</dt>
          <dd>{html.escape(apk_metadata["published_at"])}</dd>
        </dl>
      </section>
    </main>
  </body>
</html>
"""

index_path.write_text(index_html, encoding="utf-8")
PY

cat <<EOF
Published public execution hub:
  $INDEX_PATH
  $EXECUTION_JSON_PATH

Public path:
  /run/
  /run/execution.json
EOF

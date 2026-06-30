#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
PORTFOLIO_DIR="$DRIVE_ROOT/3. 포트폴리오 정리"
RUNTIME_DIR="$ROOT_DIR/runtime/portfolio_evidence"
REPORT_PATH="$PORTFOLIO_DIR/AI_PMS_MVP_실행검증_포트폴리오.md"
SUMMARY_JSON="$RUNTIME_DIR/latest_portfolio_evidence.json"

mkdir -p "$PORTFOLIO_DIR" "$RUNTIME_DIR"

export ROOT_DIR DRIVE_ROOT REPORT_PATH SUMMARY_JSON

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path


root = Path(os.environ["ROOT_DIR"])
drive_root = Path(os.environ["DRIVE_ROOT"])
report_path = Path(os.environ["REPORT_PATH"])
summary_json = Path(os.environ["SUMMARY_JSON"])


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str | None:
    if not path.exists():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
apk_metadata = load_json(root / "web_client/public/downloads/android-apk.json")
run_manifest = load_json(root / "web_client/public/run/execution.json")
handoff_package = load_json(root / "web_client/public/handoff/public-review-package.json")
install_check = load_json(root / "runtime/android_public_install/latest_install_check.json")
review_summary = load_json(root / "runtime/review_responses/latest_summary.json")

direct_apk = drive_root / "배포_APK/AI-PMS-Recorder.apk"
direct_apk_sha = sha256(direct_apk)
apk_sha = apk_metadata.get("sha256")
run_sha = (run_manifest.get("android_apk") or {}).get("sha256")
handoff_sha = (handoff_package.get("android_apk") or {}).get("sha256")

evidence = {
    "kind": "ai_pms_mvp_portfolio_evidence",
    "generated_at": generated_at,
    "scope": "recorder_first_project_member_auto_distribution_mvp",
    "core_keys": ["Project_ID", "Meeting_ID", "source_id"],
    "apk": {
        "file": "AI-PMS-Recorder.apk",
        "direct_path": str(direct_apk),
        "sha256": apk_sha,
        "direct_sha256": direct_apk_sha,
        "run_manifest_sha256": run_sha,
        "handoff_sha256": handoff_sha,
        "metadata_match": apk_sha == direct_apk_sha == run_sha == handoff_sha,
        "size_bytes": apk_metadata.get("size_bytes"),
        "layout": apk_metadata.get("layout"),
        "signing": apk_metadata.get("signing"),
        "published_at": apk_metadata.get("published_at"),
    },
    "public_urls": run_manifest.get("public_urls", {}),
    "local_urls": run_manifest.get("local_urls", {}),
    "install_check": {
        "checked_at": install_check.get("checked_at"),
        "mode": install_check.get("mode"),
        "dry_run": install_check.get("dry_run"),
        "install_status": (install_check.get("result") or {}).get("install_status"),
        "launch_status": (install_check.get("result") or {}).get("launch_status"),
    },
    "review_summary": review_summary,
    "manual_gaps": [
        "USB-connected physical Android install and recording/upload run",
        "real SMTP provider credentials",
        "real ERP endpoint credentials",
        "release APK signing with a real keystore",
        "fixed-domain Cloudflare named tunnel",
    ],
}

summary_json.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

public_urls = evidence["public_urls"]
local_urls = evidence["local_urls"]
apk = evidence["apk"]
install = evidence["install_check"]

def value_or_dash(value: object) -> str:
    return str(value) if value not in (None, "", {}) else "-"


report = f"""# AI-PMS MVP 실행검증 포트폴리오 근거

생성시각(UTC): `{generated_at}`

## 1. 포트폴리오 메시지

AI-PMS는 회의 녹음, 전사, 요약을 별도 도구로 끝내지 않고 `Project_ID`와
`Meeting_ID`를 기준으로 회의내용을 PMS 실행정보로 연결하는 플랫폼이다.
Android 앱은 녹음 중심이며, 사용자는 참석자를 수동 선택하지 않는다. 선택한
프로젝트의 참여인원이 승인 회의록 배포 대상 산정 기준이다.

## 2. 구현 범위

| 영역 | 구현 근거 |
|---|---|
| Android | A-000 녹음 홈, A-001 프로젝트 선택, A-002 프로젝트 구성원 자동 배포 확인, A-003 녹음·업로드, A-004 처리상태 |
| React Web | W-000 로그인, W-001 프로젝트 관리, W-003 회의 상태, W-004 회의록 검토, W-005 승인, W-006 이메일 배포 |
| Collection API | 업로드 세션, 오디오 파일 저장, 분석 Job, Worker Lease/Retry |
| Platform API | 사번 로그인, 프로젝트/회의, 분석결과 저장, 승인, 이메일 배포, PMS 반영 |
| Mac mini Worker | STT, 로컬 LLM 분석, JSON Schema 검증, Collection pull worker |

## 3. 실행 URL

| 구분 | URL |
|---|---|
| 실행 허브 | {value_or_dash(public_urls.get("run_hub"))} |
| Web Console | {value_or_dash(public_urls.get("web_console"))} |
| APK 다운로드 | {value_or_dash(public_urls.get("apk_file"))} |
| APK 설치 가이드 | {value_or_dash(public_urls.get("apk_install_guide"))} |
| 파트 전달안 | {value_or_dash(public_urls.get("handoff_page"))} |
| Platform API | {value_or_dash(public_urls.get("platform_docs"))} |
| Collection API | {value_or_dash(public_urls.get("collection_docs"))} |
| Analysis Server | {value_or_dash(public_urls.get("analysis_docs"))} |

로컬 실행 기준:

| 구분 | URL |
|---|---|
| Web | {value_or_dash(local_urls.get("web_client"))} |
| Platform | {value_or_dash(local_urls.get("platform_api"))} |
| Collection | {value_or_dash(local_urls.get("collection_api"))} |
| Analysis | {value_or_dash(local_urls.get("analysis_server"))} |

## 4. APK 근거

| 항목 | 값 |
|---|---|
| 파일 | `AI-PMS-Recorder.apk` |
| 직접 전달 경로 | `{apk["direct_path"]}` |
| SHA256 | `{value_or_dash(apk["sha256"])}` |
| 크기 | `{value_or_dash(apk["size_bytes"])}` bytes |
| 레이아웃 | `{value_or_dash(apk["layout"])}` |
| 서명 | `{value_or_dash(apk["signing"])}` |
| 게시시각 | `{value_or_dash(apk["published_at"])}` |
| 실행 허브/전달안/직접 APK 해시 일치 | `{apk["metadata_match"]}` |

## 5. 설치검증 상태

| 항목 | 값 |
|---|---|
| 확인시각 | `{value_or_dash(install["checked_at"])}` |
| 모드 | `{value_or_dash(install["mode"])}` |
| Dry-run | `{value_or_dash(install["dry_run"])}` |
| 설치 상태 | `{value_or_dash(install["install_status"])}` |
| 실행 상태 | `{value_or_dash(install["launch_status"])}` |

실기기 설치 전 자동 검증은 파일 존재, 해시, 패키지명, adb 명령 구성까지 확인한다.
실제 Android 기기 녹음/업로드는 USB 기기 연결 후 별도 수동 검증이 필요하다.

## 6. 검증 명령

```bash
bash scripts/smoke_mvp_scope_definition.sh
bash scripts/smoke_screen_design_ui.sh
bash scripts/smoke_android_release_readiness.sh
AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh
bash scripts/verify_mvp_static.sh
```

## 7. 산출물 연결

| 산출물 | 경로 |
|---|---|
| 요구사항정의서 | `2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md` |
| 화면/API 매핑 | `1. 화면설계서/화면별_API_매핑.md` |
| 작업 구조 | `ai_pms_bootstrap/docs/09_kim_heeseop_work_structure.md` |
| MVP 구현 현황 | `ai_pms_bootstrap/docs/15_mvp_first_implementation.md` |
| 실행 허브 manifest | `ai_pms_bootstrap/web_client/public/run/execution.json` |
| 파트 전달 패키지 | `ai_pms_bootstrap/web_client/public/handoff/public-review-package.json` |
| 설치검증 리포트 | `배포_APK/설치검증_리포트.md` |
| 릴리즈 서명 준비상태 | `배포_APK/릴리즈서명_준비상태.md` |

## 8. 수동 미검증/후속 항목

| 항목 | 이유 |
|---|---|
| 실기기 녹음·업로드 E2E | USB 연결 Android 기기 필요 |
| SMTP 실제 발송 | 실제 SMTP 계정/비밀번호 필요 |
| ERP 실제 전송 | 운영 ERP endpoint와 인증정보 필요 |
| release APK 생성 | 실제 keystore/password 필요 |
| 고정 도메인 | Cloudflare named tunnel ID와 DNS hostname 필요 |

## 9. 차별화 문장

- 참석자 수동 선택 없음: 프로젝트만 선택하고 프로젝트 참여인원 기준으로 자동 배포한다.
- 화자 임의 추정 없음: 회의내용은 안건, 논의, 결정, 후속조치 중심으로 구조화한다.
- 승인 전 자동 확정 없음: AI 결과는 후보이며 Web 검토·승인 후 PMS 데이터로 반영한다.
- 로컬 분석 기반: Mac mini의 STT/LLM Worker가 Collection Job을 pull 처리한다.
- PMS 확장성: Task, Decision, Risk, Resource, Knowledge가 `Project_ID`로 연결된다.
"""

report_path.write_text(report, encoding="utf-8")

print(f"Portfolio evidence summary: {summary_json}")
print(f"Portfolio evidence report: {report_path}")
PY

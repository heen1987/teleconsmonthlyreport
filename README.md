# AI-PMS Bootstrap

이 저장소는 `Project_ID` 중심의 AI-PMS(Project Management System)를 만들기
위한 로컬 PoC 스캐폴드입니다.

제품의 메인 범위는 PMS입니다. 회의 음성녹음 수집, STT, LLM 분석, 회의록
검토/승인, 배포는 PMS 안에 들어가는 첫 번째 AI 자동화 모듈입니다.

권장 프로젝트명:

> 로컬 LLM 기반 AI-PMS 및 회의정보 지능화 모듈 개발

## Scope

PMS 기본 범위:

- 프로젝트 코어, 구성원, 권한, 감사
- 일정, 마일스톤, WBS
- 업무, 이슈, 의사결정
- 자원 수요, 배정, 예약, 사용 실적
- 비용 입력 및 위험 후보 관리
- 문서, 지식, 알림, 배포 이력
- AI 보조 모듈, 첫 모듈은 회의정보 지능화

1차 AI 모듈 범위:

- Android에서 프로젝트 선택 후 회의 음성 업로드
- Collection API가 업로드 세션, 파일 검증, 분석 job/lease 관리
- Mac mini Analysis Worker가 STT와 로컬 LLM 분석 수행
- Platform API가 분석 결과, 회의록 초안, 승인, 배포, PMS 반영 관리
- 승인된 Action Item을 PMS Task 후보로 전환
- 결정사항, 위험, 필요 자원 후보를 프로젝트 지식으로 축적

## Stack

- Current local PoC backend: FastAPI
- Current local PoC database: PostgreSQL
- Vector extension: pgvector
- Local LLM runtime: Ollama
- LLM target: Qwen3 4B/8B class model
- STT: Whisper.cpp

Drive 기준 목표 문서에는 Platform API, Collection API 모두 Flask/MySQL/Redis/RQ
후보로 적혀 있습니다. 현재 로컬 Mac mini PoC는 빠른 검증을 위해
FastAPI/PostgreSQL로 구성되어 있으며, `docs/08_drive_based_reconfiguration.md`에
목표 구조와 전환 절차를 분리해 두었습니다.

## Drive Source Root

기준 기획/설계 문서의 로컬 Google Drive 동기화 루트:

```text
/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1
```

자동화 개발 루프와 설계 검토는 이 폴더의 `README.md`,
`2. 요구사항정의서/`, `1. 화면설계서/`, `5. 프로젝트관리/작업백로그.md`,
`4. 협업가이드/협업_운영가이드.md`를 우선 기준으로 삼습니다.

The current Web visualization pass uses the image set in `1. 화면설계서/` as
the reference for the MEETFLOW PMS workspace: navy product shell, KPI strip,
task board, document area, meeting review panel, and Android phone preview.

Model shortlist for the 16GB Mac mini M4:

- [MVP Requirements Definition](docs/23_mvp_requirements_definition.md)
- [Local LLM Recommendations](docs/04_local_llm_recommendations.md)
- [Mac mini Analysis Server Plan](docs/05_mac_mini_analysis_server.md)
- [Platform To Analysis Server Integration](docs/06_platform_analysis_integration.md)
- [Part Handoff Drafts](docs/18_part_handoff_drafts.md)

## Target Service Split

Drive 기준 목표 서비스 경계:

- `backend/`: PMS Platform API. 프로젝트, 사용자, 회의, 분석 결과, 회의록, 승인, 배포, PMS 반영의 기준 API.
- `collection_api/`: Collection API. 업로드 세션, 음성 파일 메타데이터, 분석 job, worker lease, retry 관리.
- `analysis_server/`: Mac mini Analysis Worker/API. STT, 회의내용 중심 구조화, Ollama 기반 LLM 분석, JSON 초안 생성.
- Android App: 프로젝트 선택, 녹음, 업로드, 상태 확인.
- React Web: 프로젝트 관리, 회의록 검토, 승인, 배포, 사용자 관리.

현재 PoC 연결:

```text
backend /meetings/analyze
  -> Collection API upload session + transcript analysis job
  -> Mac mini Analysis Worker claims Collection job
  -> analysis_server local STT/LLM service layer
  -> Collection API stores completed result
  -> meeting_analyses draft
  -> approval endpoint reflects approved results into PMS task/decision/knowledge data
```

현재 1차 구현에서는 transcript 기반 Platform 분석 경로, Collection 오디오 업로드
경로, 분석 완료 후 key-id 기반 signed Platform callback 저장 경로, callback
retry/backoff와 secret rotation 검증이 연결되어 있습니다. Platform 로그인은
DB 해시 저장 기반 bearer access token을 발급하고 `/users/me`, `/users/logout`에서
검증합니다. 사용자 대상 Platform API는 초기 비밀번호 변경을 마친 활성 bearer
token이 있어야 프로젝트, 회의, 승인, 대시보드, task, resource 경로에 접근할 수
있습니다. 공개 `/users` 생성/목록 API는 닫혀 있고, 사용자 등록은 활성 관리자
bearer token이 필요한 `/admin/users`로만 수행합니다. React Web은 사번 로그인,
초기 비밀번호 변경, 토큰 검증 후 승인 전 검토 수정과 후보 제외까지 수행합니다.
승인된 회의록은 Web에서 배포 미리보기 후 `dev_log` 발송 기록과 수신자별
delivery attempt를 남길 수 있습니다. Platform 이메일 배포는 기본 `dev_log`
모드로 동작하며, SMTP 환경변수를 설정하면 같은 delivery/retry 경로로 실제
발송을 시도할 수 있습니다.
승인된 필수 자원 후보는 Resource Demand가 되고, 이후 사람/API가
Resource Pool profile 가용성을 확인한 뒤 assignment/reservation allocation으로
전환할 수 있습니다. 같은 자원명 또는 같은 `resource_id`의 겹치는 기간 활성
allocation은 충돌 기록으로 남겨 후속 위험/자원 관리 흐름에 연결합니다.
승인된 회의 요약, 결정사항, Action Item, 리스크, 필요 자원은
`project_knowledge_items`에 저장되고 `/projects/{project_id}/knowledge-items`에서
Project_ID 기준으로 조회할 수 있습니다. React Web 시각화 콘솔은 프로젝트와
항목 종류별로 이 지식 항목을 탐색할 수 있습니다.
승인된 비용 후보는 finance/admin이 외부 ERP handoff queue에 넣을 수 있고,
기본 `dev_log` 또는 설정된 HTTP connector를 통해 송신한 뒤 외부 ERP 응답을
별도 reconciliation 단계에서 `accepted/rejected/failed`로 반영합니다.
운영자는 Web 시각화 콘솔에서 email delivery와 ERP handoff retry queue의
attention count와 due retry 상태를 확인하고, due email retry와 due ERP
handoff 송신을 같은 콘솔에서 실행할 수 있습니다. 대시보드는 지연 업무,
미해결 리스크, 자원 충돌, 배포 실패 KPI도 함께 표시해 회의 분석 결과가
프로젝트 실행 위험으로 이어지는 지점을 빠르게 확인할 수 있습니다.
운영자는 Attention KPI에서 지연 업무를 규칙 기반 Risk 후보로 승격할 수
있고, 같은 Task를 중복 리스크로 만들지 않도록 `task_delay` 근거 marker와
감사로그를 남깁니다.
운영자는 Cost Feedback에서 기준 금액을 초과한 비용 후보도 규칙 기반 Risk
후보로 승격할 수 있고, 같은 Cost Candidate를 중복 리스크로 만들지 않도록
`cost_threshold` 근거 marker와 감사로그를 남깁니다.
운영자는 Resource Pool에서 자원 배정/예약 충돌도 규칙 기반 Risk 후보로
승격할 수 있고, 같은 Allocation 충돌을 중복 리스크로 만들지 않도록
`resource_conflict` 근거 marker와 감사로그를 남깁니다.
운영자는 Resource Pool에서 시작일이 도래한 미배정 Resource Demand도 규칙 기반
Risk 후보로 승격할 수 있고, 같은 Demand를 중복 리스크로 만들지 않도록
`resource_unassigned` 근거 marker와 감사로그를 남깁니다.
운영자는 Cost Feedback에서 allocation 수량을 초과한 사용실적도 규칙 기반
Risk 후보로 승격할 수 있고, 같은 Usage를 중복 리스크로 만들지 않도록
`resource_usage_overrun` 근거 marker와 감사로그를 남깁니다.
관리자는 React Web에서 사용자 등록, 목록 조회, 역할/상태 수정, 비밀번호 초기화를
수행할 수 있습니다. 사용자는 로그인 전 사번과 등록 이메일로 비밀번호 재설정
토큰을 요청하고 새 비밀번호를 설정할 수 있습니다.
Android도 사번 로그인, 토큰 저장/복구, 초기 비밀번호 변경 후 프로젝트 선택,
프로젝트 구성원 자동 배포 확인, 녹음, 업로드, 분석 상태 확인을 수행하는 1차 네이티브
클라이언트가 추가되었습니다.

## Local Mac Mini Setup

Installed local components:

- PostgreSQL 17 with `pgvector`
- Python 3.12 virtual environments for `backend/` and `analysis_server/`
- Ollama with Qwen3 4B as the default analysis model
- Additional local model candidates: Granite 4.1 3B, Kanana 2.1B Q3, Gemma 3 4B, LFM2.5 1.2B
- Whisper.cpp with `models/whisper/ggml-small.bin`
- Android command-line build chain: `openjdk@21`, `gradle@8`, Android SDK Platform 35, Build-Tools 35.0.0
- Android emulator: `ai_pms_api35`, API 35 Google APIs ARM64

Environment files are already configured:

- `backend/.env`
- `collection_api/.env`
- `analysis_server/.env`

Database schema is migration-managed:

- `backend/migrations/0001_platform_initial.sql`
- `backend/migrations/0002_password_reset_tokens.sql`
- `backend/migrations/0003_email_distributions.sql`
- `backend/migrations/0004_email_delivery_retry.sql`
- `backend/migrations/0005_resource_allocation.sql`
- `backend/migrations/0006_resource_profiles.sql`
- `collection_api/migrations/0001_collection_initial.sql`
- `scripts/run_migrations.py`

The service run scripts apply pending migrations automatically and record them
in `schema_migrations`. See `docs/17_database_migration_policy.md`.

Start services in separate terminals:

```bash
cd ai_pms_bootstrap
bash scripts/run_postgres.sh
bash scripts/run_collection_api.sh
bash scripts/run_analysis_server.sh
bash scripts/run_analysis_worker_loop.sh
bash scripts/run_platform_backend.sh
```

Start the local web/app execution stack in reusable `screen` sessions:

```bash
cd ai_pms_bootstrap
bash scripts/run_local_execution_stack.sh
```

Run the React Web client:

```bash
cd ai_pms_bootstrap/web_client
npm install
npm run dev
```

Run due email delivery retries once:

```bash
cd ai_pms_bootstrap
bash scripts/run_email_delivery_worker_once.sh
```

Run queued or due ERP cost handoffs once:

```bash
cd ai_pms_bootstrap
bash scripts/run_erp_handoff_worker_once.sh
```

Run all due operations recovery workers once:

```bash
cd ai_pms_bootstrap
bash scripts/run_operations_recovery_once.sh
```

Install an hourly macOS LaunchAgent for operations recovery:

```bash
cd ai_pms_bootstrap
bash scripts/install_launchd_operations_recovery.sh --check
bash scripts/install_launchd_operations_recovery.sh --install
bash scripts/install_launchd_operations_recovery.sh --load
```

LAN access from another device on the same Wi-Fi/Ethernet network:

```bash
cd ai_pms_bootstrap
bash scripts/print_lan_urls.sh
```

The Web client uses the current browser host as its default Platform API host,
so opening `http://<Mac-mini-LAN-IP>:3000` will call
`http://<Mac-mini-LAN-IP>:8000`.

Open the Android client project after installing Android Studio/JDK:

```bash
cd ai_pms_bootstrap/android_client
./gradlew assembleDebug
```

Or use the environment-safe repository script:

```bash
cd ai_pms_bootstrap
bash scripts/build_android_debug.sh
```

Run the headless Android emulator and install the debug app:

```bash
cd ai_pms_bootstrap
bash scripts/run_android_emulator.sh
bash scripts/install_android_debug.sh
```

Build/install for a physical Android device on the same LAN as the Mac mini:

```bash
cd ai_pms_bootstrap
bash scripts/smoke_lan_access.sh
bash scripts/build_android_lan_debug.sh
bash scripts/install_android_physical_lan_debug.sh
```

The LAN build injects `http://<Mac-mini-LAN-IP>:8000` and
`http://<Mac-mini-LAN-IP>:8200` as the Android app defaults. USB debugging must
be enabled on the device before the install script can run.

Temporary public access through Cloudflare quick tunnels:

```bash
cd ai_pms_bootstrap
bash scripts/run_public_tunnels.sh
bash scripts/refresh_public_handoff_bundle.sh
```

The public execution hub is served at `/run/` and links to Web, APK,
Platform, Collection, Analysis, handoff, and the execution JSON manifest.

If the APK must be rebuilt against the current tunnel URLs, run:

```bash
bash scripts/build_android_public_debug.sh
AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh
```

USB-connected public APK install verification:

```bash
AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh
bash scripts/install_android_public_debug_apk.sh
```

The public build injects the active Platform and Collection tunnel URLs into
the responsive phone/tablet debug APK and writes it to
`artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk`.
The publish script also exposes the APK through the Web client at
`/downloads/`.
For external testers, the same APK is also published as the simpler install
file `AI-PMS-Recorder.apk`; the longer `AiPmsAndroidClient-responsive-public-debug.apk`
name is retained for build traceability.
The direct Drive handoff copy is also available at
`../배포_APK/AI-PMS-Recorder.apk` for non-zip APK sharing.
The execution hub script exposes the current run paths and commands at
`/run/` and `/run/execution.json`.
React public routes read `/run/execution.json` first, so refreshed tunnel URLs
are used by `/run/`, `/downloads/`, and `/handoff/` when the manifest is
available.
The APK install guide at `/downloads/install.html` gives phone/tablet layout
checks and the recording/upload/status verification flow for testers.
The review package script exposes reviewer URLs, APK details, owner scopes,
and the required verification order at `/handoff/public-review-package.json`.
The review response template at `/handoff/review-response-template.md` gives
each owner the same approval/change/question/unverified response format.
Filled responses can be placed in `runtime/review_responses/inbox/` and
summarized with `bash scripts/collect_public_review_responses.sh`.
The refresh script writes the latest local summary to
`runtime/public_handoff/latest_refresh.json`.
Run the non-mutating public handoff doctor before sharing links:

```bash
bash scripts/doctor_public_handoff.sh
```

The doctor writes `runtime/public_handoff/latest_doctor.json` and
`runtime/public_handoff/latest_doctor.md`, then checks public handoff files, APK
hashes, requirements hashes, tunnel DNS, local service health, and the latest
public smoke status.
`scripts/smoke_public_access.sh` verifies the public download and handoff
routes, review package JSON, APK metadata/file availability, API health checks,
and Platform CORS before the links are shared externally.
It accepts explicit Web, Platform, Collection, and Analysis URLs before falling
back to `AIPMS_PUBLIC_*_URL` environment variables and `runtime/tunnels/*.log`:

```bash
bash scripts/smoke_public_access.sh "$WEB_URL" "$PLATFORM_URL" "$COLLECTION_URL" "$ANALYSIS_URL"
```

If a Cloudflare quick tunnel URL has expired, refresh with:

```bash
RESTART_PUBLIC_TUNNELS=1 AIPMS_REFRESH_START_TUNNELS=1 bash scripts/refresh_public_handoff_bundle.sh
```

Fixed-domain Cloudflare named tunnel preparation:

```bash
cd ai_pms_bootstrap
bash scripts/prepare_cloudflare_named_tunnel.sh
```

With Cloudflare tunnel ID and hostname environment variables exported, the
script writes `runtime/cloudflare_named_tunnel/config.yml`. Start it with:

```bash
bash scripts/run_cloudflare_named_tunnel.sh
```

See `docs/19_cloudflare_named_tunnel_plan.md` for the required DNS hostnames,
environment variables, and Android public build handoff after the fixed tunnel
is live.

Android release-signing preparation:

```bash
cd ai_pms_bootstrap
bash scripts/prepare_android_release_signing.sh
```

After a keystore and signing environment variables are ready:

```bash
bash scripts/build_android_release_apk.sh
```

See `docs/20_android_release_signing.md` before sharing a release APK.

Android Studio is still useful for GUI emulator/device operation, but the
command-line debug APK build, emulator install, app launch, and project API
lookup have been verified. See `android_client/README.md`.

Connectivity smoke test:

```bash
cd ai_pms_bootstrap
bash scripts/smoke_analysis_connection.sh
```

Static MVP verification:

```bash
cd ai_pms_bootstrap
bash scripts/verify_mvp_static.sh
```

## Quick Start

```bash
cd ai_pms_bootstrap
bash scripts/run_postgres.sh
```

Run the Mac mini analysis server:

```bash
bash scripts/run_analysis_server.sh
```

Run the Mac mini analysis worker loop:

```bash
bash scripts/run_analysis_worker_loop.sh
```

Run PostgreSQL if Homebrew services are not active:

```bash
bash scripts/run_postgres.sh
```

Run the Platform backend:

```bash
bash scripts/run_platform_backend.sh
```

Apply database migrations manually when needed:

```bash
bash scripts/apply_platform_schema.sh
bash scripts/apply_collection_schema.sh
```

Open:

- API health: http://127.0.0.1:8000/health
- Swagger UI: http://127.0.0.1:8000/docs
- Collection API health: http://127.0.0.1:8200/health
- Collection API Swagger UI: http://127.0.0.1:8200/docs
- Analysis server health: http://127.0.0.1:8100/health
- Analysis server Swagger UI: http://127.0.0.1:8100/docs
- Platform to analysis health: http://127.0.0.1:8000/integrations/analysis-server/health

Connectivity smoke test:

```bash
bash scripts/smoke_analysis_connection.sh
```

Audio upload/STT/LLM/signed-callback/replay/retry smoke test:

```bash
bash scripts/smoke_audio_upload_job.sh
```

Callback secret rotation smoke test:

```bash
bash scripts/smoke_callback_secret_rotation.sh
```

Auth token smoke test:

```bash
bash scripts/smoke_auth_tokens.sh
```

Admin-only user registration smoke test:

```bash
bash scripts/smoke_admin_user_registration.sh
```

Demo admin credential smoke test:

```bash
bash scripts/smoke_demo_admin_credentials.sh
```

Password reset smoke test:

```bash
bash scripts/smoke_password_reset.sh
```

Resource allocation/conflict smoke test:

```bash
bash scripts/smoke_resource_allocation.sh
```

Resource profile/availability smoke test:

```bash
bash scripts/smoke_resource_profiles.sh
```

Project knowledge index smoke test:

```bash
bash scripts/smoke_project_knowledge_index.sh
```

Protected Platform API smoke test:

```bash
bash scripts/smoke_protected_platform_api.sh
```

Seed a local demo/admin user directly into the database:

```bash
bash scripts/seed_demo_admin.sh
```

The local demo admin login is employee number `admin` with password `1234`.
The seed command keeps the account `active` and revokes existing admin tokens
when the password is reset.

Build the 50-person SW company demo plan and optionally apply it to the local
Platform DB:

```bash
backend/.venv/bin/python scripts/seed_demo_company.py
backend/.venv/bin/python scripts/seed_demo_company.py --apply
bash scripts/smoke_demo_company_seed.sh
```

## Core Flow

```text
PMS Project
  -> Meeting created with Project_ID
  -> Android upload session requested
  -> Collection API receives and validates audio
  -> Collection API creates analysis job
  -> Mac mini Analysis Worker claims job
  -> STT transcript generated
  -> LLM analysis JSON generated
  -> Platform API stores draft analysis/minutes
  -> Web user reviews and approves
  -> Approved action items become PMS task candidates
  -> Decisions, risks, resource demands, knowledge, and distribution records are stored
  -> Resource Pool profiles expose availability by date window
  -> Resource demands become assignment/reservation allocations with conflict checks
  -> Audit log is stored
```

## Guardrail

LLM output is always treated as a draft, candidate, summary, or explanation.
Anything that changes official PMS data, accounting journals, budget usage, or
approval state must pass deterministic rules and human approval.

# MVP First Implementation

Last updated: 2026-06-30

## Implemented Modules

### Platform API

- users and employee-number login
- admin-only user registration/list APIs
- admin-only user update and password reset APIs
- disabled public user collection create/list routes
- migration-managed PostgreSQL schema application
- bearer access token issue, verify, and logout
- password change
- email-matched password reset request, verify, and confirm APIs
- active bearer guard for user-facing project, meeting, review, approval,
  dashboard, task, and resource APIs
- projects
- project description field and project update API for Web W-001 project
  management contract
- project members
- project member detail contract includes member email and user role for
  project-member automatic distribution confirmation
- project member standalone list and delete APIs for Web W-002 participation
  management contract
- project detail
- meetings
- recent meeting status list for Web W-003/W-visual operations
- single meeting status API for Android A-004 and Web W-003
- analysis review package
- review-edit API before approval
- Collection job completion callback
- signed Collection callback verification
- managed Collection callback key-id rotation
- approval
- email distribution preview
- dev-log email distribution and delivery attempts
- SMTP-ready email delivery mode and retry metadata
- email distribution manual retry and retry-due worker endpoint
- task candidates
- decision records
- project knowledge items from approved meeting analysis
- resource demand candidates
- resource profile pool records
- resource profile availability lookup
- resource capacity calendar block records
- resource assignment/reservation allocation records
- resource duplicate-window conflict detection
- resource usage entries and project cost candidate feedback
- finance/PM cost candidate approval and rejection gate
- approved cost ERP handoff queue
- ERP cost handoff delivery connector and retry worker path
- ERP cost handoff response reconciliation
- operations queue status API for email and ERP retry visibility
- operations queue recovery APIs wired into the Web visual console
- hourly macOS LaunchAgent installer for due operations recovery
- risk candidates
- overdue task to risk candidate promotion
- cost candidate threshold to risk candidate promotion
- resource allocation conflict to risk candidate promotion
- unassigned resource demand to risk candidate promotion
- resource usage overrun to risk candidate promotion
- dashboard summary including resource usage, candidate cost, and knowledge counts
- dashboard attention KPIs for overdue tasks, unresolved risks, resource
  conflicts, and distribution failures
- Web visual workspace now includes a transcript-note workbench benchmarked
  against Korean AI note/transcription service patterns: note navigation,
  note list, content-segment/timestamp transcript, AI memo summary, player bar, and
  project-member automatic distribution cue
- Android native surface is recorder-first: the entry screen prioritizes
  project selection, Meeting ID, recording start/stop, upload/analyze, and
  status check while preserving project-member automatic distribution policy

### Collection API

- upload sessions
- migration-managed PostgreSQL schema application
- multipart audio file upload with upload token
- audio asset metadata
- analysis job creation
- worker heartbeat
- worker job claim
- job start/complete/fail
- Platform callback on job completion
- callback event list and manual replay
- automatic Platform callback retry/backoff
- callback signing key id header for active/previous secret rotation
- expired lease requeue
- job list/detail

### Mac Mini Analysis Worker

- existing STT/LLM analysis endpoint
- Whisper.cpp STT endpoint
- `analysis.v1` structured result contract
- Collection API heartbeat/claim/start/complete/fail client
- pull-mode worker command for Collection transcript jobs
- pull-mode worker command for Collection audio asset jobs
- local LLM analysis result completion back into Collection API

### React Web

- employee-number login screen
- initial password change screen
- password reset request and confirmation screens
- admin-only user management screen
- admin user create/list/update/password reset actions
- bearer token storage and `/users/me` verification
- logout action with token revocation
- dashboard summary
- dashboard attention KPI cards
- overdue task risk-promotion action in the visual console
- knowledge item count metric
- project knowledge explorer with project and item-kind filters
- project knowledge search and evidence drill-down
- recent meeting processing status visualization
- selected project detail loading for Web project staffing visibility
- project member allocation, planned M/M, staffing cost, and role display in
  the visual console
- project member email display in the Web staffing panel
- resource usage and cost candidate feedback visualization
- resource calendar block availability indicator
- resource conflict risk-promotion action in the visual console
- unassigned resource demand risk-promotion action in the visual console
- resource usage overrun risk-promotion action in the visual console
- cost candidate approve/reject actions in the visual console
- cost candidate risk-promotion action in the visual console
- operations queue status card for email delivery and ERP handoff retries
- operations queue due email retry and ERP handoff send-due actions
- project selection
- meeting review package loading
- approval action
- email distribution preview and send action
- distribution delivery-log panel
- action item, decision, risk, resource, transcript sections
- Drive screen-design-based MEETFLOW/PMS workspace composition
- desktop visual console with sidebar navigation, KPI strip, task board,
  document space, meeting review/approval panel, and Android phone preview
- browser-framed Web design surface covering WEB-01 workspace, WEB-02 kanban
  board, WEB-03 document space, WEB-04 review/approval, and ADMIN-01 operations
  dashboard reference sections
- APP-01 to APP-05 app-flow preview inside the Web visual console
- responsive Web layout validated at phone width for tablet/phone handoff review

### Android

- Android native app project scaffold
- command-line Android build environment on the Mac mini
- Gradle wrapper and debug APK build script
- physical-device LAN debug APK build and install scripts
- Android Emulator API 35 AVD and install script
- employee-number login section
- bearer token storage and `/users/me` session restore
- initial password change section
- Platform API Authorization header on project/member/distribution calls
- project selection screen
- project-member auto distribution target section
- project-member auto distribution target email display
- no attendee manual selection before upload
- Android client excludes attendee-save API contracts from the packaged app
- recording/upload/status screen
- manual Meeting_ID-based Platform status refresh
- runtime microphone permission request
- MediaRecorder AAC/M4A recording
- Ktor Android client for Platform and Collection APIs
- upload session, multipart upload, analysis job creation, status polling
- Android-uploaded M4A STT conversion with FFmpeg before Whisper
- Kotlin DTOs for project, upload session, audio asset, upload file, analysis job
- Kotlin API client interface and repository orchestration
- tester-facing responsive APK alias `AI-PMS-Recorder.apk`
- direct Drive handoff copy at `../배포_APK/AI-PMS-Recorder.apk`
- direct APK README, checksum, manifest, install report, Web download
  metadata, review package, and execution hub are regenerated from the current
  APK hash instead of a hardcoded checksum
- APP-01 to APP-05 native UI order: recorder-first home, project selection,
  meeting settings, recording, and upload/analysis status

## Run Order

```bash
bash scripts/run_postgres.sh
bash scripts/run_collection_api.sh
bash scripts/run_analysis_server.sh
bash scripts/run_platform_backend.sh
```

The Platform and Collection run scripts apply pending service migrations before
starting each API.

Web:

```bash
cd web_client
npm install
npm run dev
```

Worker loop:

```bash
bash scripts/run_analysis_worker_loop.sh
```

## Verification

```bash
bash scripts/verify_mvp_static.sh
```

Auth token verification smoke test:

```bash
bash scripts/smoke_auth_tokens.sh
```

Protected Platform API smoke test:

```bash
bash scripts/smoke_protected_platform_api.sh
```

Project member detail and legacy attendee API smoke test:

```bash
bash scripts/smoke_meeting_attendees.sh
```

Admin-only user registration smoke test:

```bash
bash scripts/smoke_admin_user_registration.sh
```

This smoke test also verifies admin user update, password reset, token
revocation, and forced password-change state after reset.

Demo admin credential smoke test:

```bash
bash scripts/smoke_demo_admin_credentials.sh
```

The local demo administrator is seeded as `admin / 1234` in `active` state.

Password reset smoke test:

```bash
bash scripts/smoke_password_reset.sh
```

MVP scope definition smoke test:

```bash
bash scripts/smoke_mvp_scope_definition.sh
```

Email distribution smoke test:

```bash
bash scripts/smoke_email_distribution.sh
```

Email delivery retry smoke test:

```bash
bash scripts/smoke_email_retry.sh
```

Resource allocation and conflict smoke test:

```bash
bash scripts/smoke_resource_allocation.sh
```

Resource conflict risk promotion smoke test:

```bash
bash scripts/smoke_resource_conflict_risk_promotion.sh
```

This verifies authenticated APMS-FR-033 promotion, allocation-conflict source
creation, idempotent risk creation, project-detail risk/conflict counts,
evidence markers, and audit logging.

Unassigned resource demand risk promotion smoke test:

```bash
bash scripts/smoke_unassigned_resource_demand_risk_promotion.sh
```

This verifies authenticated APMS-FR-033 unassigned-demand promotion,
candidate/future/assigned filtering, idempotent risk creation, project-detail
risk/demand counts, evidence markers, and audit logging.

Resource profile and availability smoke test:

```bash
bash scripts/smoke_resource_profiles.sh
```

Resource calendar block smoke test:

```bash
bash scripts/smoke_resource_calendar_blocks.sh
```

Resource usage and cost candidate smoke test:

```bash
bash scripts/smoke_resource_usage_cost.sh
```

This also verifies finance-only ERP handoff queue creation for approved cost
candidates and accepted/rejected/failed reconciliation guards.

Resource usage overrun risk promotion smoke test:

```bash
bash scripts/smoke_resource_usage_overrun_risk_promotion.sh
```

This verifies authenticated APMS-FR-033 usage-overrun promotion,
overrun/normal usage filtering, idempotent risk creation, project-detail risk
counts, evidence markers, and audit logging.

Cost candidate risk promotion smoke test:

```bash
bash scripts/smoke_cost_candidate_risk_promotion.sh
```

This verifies authenticated `COST_EXCEEDED` promotion, threshold/currency
filtering, idempotent risk creation, project-detail risk counts, evidence
markers, and audit logging.

ERP handoff delivery smoke test:

```bash
bash scripts/smoke_erp_handoff_delivery.sh
```

This verifies finance-only handoff delivery, duplicate-send guards, failed HTTP
handoff retry metadata, due handoff processing, and post-delivery
reconciliation.

Operations queue status smoke test:

```bash
bash scripts/smoke_operation_queue_status.sh
```

This verifies authenticated `/operations/queue-status` visibility for email
delivery retry and ERP handoff retry queues, then processes the same due rows
through `/distributions/retry-due` and `/resources/cost-handoffs/send-due`.

Project knowledge index smoke test:

```bash
bash scripts/smoke_project_knowledge_index.sh
```

This verifies approval-time knowledge item creation, authenticated project
knowledge listing, item-kind filtering, query filtering, project detail counts,
and dashboard summary counts.

Run due email delivery retries once:

```bash
bash scripts/run_email_delivery_worker_once.sh
```

Run queued or due ERP cost handoffs once:

```bash
bash scripts/run_erp_handoff_worker_once.sh
```

Run all due operations recovery workers once:

```bash
bash scripts/run_operations_recovery_once.sh
```

Run the full local execution stack in reusable terminal sessions:

```bash
bash scripts/run_local_execution_stack.sh
```

The local stack runner reuses existing service screens only after their local
health URLs return HTTP 200. Stale Collection, Analysis, Platform, and Web
screens are restarted automatically. Set
`AIPMS_LOCAL_STACK_REUSE_HEALTH_CHECK=0` only for manual screen-reuse debugging.

Validate or install an hourly macOS LaunchAgent for operations recovery:

```bash
bash scripts/install_launchd_operations_recovery.sh --check
bash scripts/install_launchd_operations_recovery.sh --install
bash scripts/install_launchd_operations_recovery.sh --load
```

Database migration verification:

```bash
bash scripts/apply_platform_schema.sh
bash scripts/apply_platform_schema.sh
bash scripts/apply_collection_schema.sh
bash scripts/apply_collection_schema.sh
```

LAN access and physical-device Android build verification:

```bash
bash scripts/smoke_lan_access.sh
bash scripts/build_android_lan_debug.sh
```

Temporary public tunnel and responsive Android APK verification:

```bash
bash scripts/run_public_tunnels.sh
bash scripts/refresh_public_handoff_bundle.sh
```

The quick tunnel runner health-checks the latest logged public URL before
reusing an existing tunnel screen session. Stale tunnel sessions are restarted
automatically. Set `AIPMS_PUBLIC_TUNNEL_REUSE_HEALTH_CHECK=0` only for manual
debugging of legacy reuse behavior.

The public execution hub is published to `/run/` and `/run/execution.json`
during refresh.
React public routes use that execution manifest as the primary source for
current public URLs and Android APK metadata.

Use `AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh`
when the APK must be rebuilt against the current tunnel URLs.

Published public APK device install check:

```bash
AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh
bash scripts/install_android_public_debug_apk.sh
```

The tester-facing APK alias is `AI-PMS-Recorder.apk`; the longer
`AiPmsAndroidClient-responsive-public-debug.apk` filename remains available
for build traceability.

Direct Drive APK handoff path:

```text
../배포_APK/AI-PMS-Recorder.apk
```

The same folder includes non-zip validation aids:

- `../배포_APK/README.md`
- `../배포_APK/AI-PMS-Recorder.sha256`
- `../배포_APK/apk_manifest.json`
- `../배포_APK/설치검증_리포트.md`

Screen-design-based Web/App UI verification:

```bash
bash scripts/smoke_screen_design_ui.sh
AIPMS_SCREEN_UI_BUILD=1 bash scripts/smoke_screen_design_ui.sh
```

The current MEETFLOW workspace UI reflects the Drive `1. 화면설계서` image set:
navy product shell, PMS task board, document workspace, meeting review status,
and Android recording/upload preview. The smoke script verifies the Web
screen markers, Android APP-01 to APP-05 markers, direct APK checksum, and
APK manifest metadata. A 390px-width responsive check verified that the
workspace panels and phone preview fit within a mobile viewport.

Collect owner review responses:

```bash
bash scripts/collect_public_review_responses.sh
```

`scripts/smoke_public_access.sh` verifies the public run hub, public download and handoff
routes, install guide, review package JSON, review response template, APK
metadata/file availability, API health checks, and Platform CORS before the
links are shared externally.

Fixed-domain Cloudflare named tunnel preparation:

```bash
bash scripts/prepare_cloudflare_named_tunnel.sh
bash scripts/run_cloudflare_named_tunnel.sh
```

The run script requires `runtime/cloudflare_named_tunnel/config.yml`, generated
after Cloudflare tunnel ID and hostname environment variables are provided.

Android release-signing preparation:

```bash
bash scripts/prepare_android_release_signing.sh
bash scripts/smoke_android_release_readiness.sh
bash scripts/build_android_release_apk.sh
```

The release build requires real keystore/password environment variables and
outputs `artifacts/apk/AiPmsAndroidClient-responsive-release.apk`. The release
build path uses a temporary local directory by default and the readiness report
is copied to `../배포_APK/릴리즈서명_준비상태.md`.

Portfolio evidence bundle:

```bash
bash scripts/export_portfolio_evidence_bundle.sh
bash scripts/smoke_portfolio_evidence_bundle.sh
```

The bundle writes
`../3. 포트폴리오 정리/AI_PMS_MVP_실행검증_포트폴리오.md` and
`runtime/portfolio_evidence/latest_portfolio_evidence.json`. It verifies APK
`metadata_match` across the direct Drive APK, Web APK metadata, public run
manifest, and public review package, then records the current Web/API/APK
execution evidence and remaining external verification gaps.

End-to-end transcript analysis flow verified:

```text
Platform /meetings/analyze
  -> Collection upload session
  -> Collection analysis job
  -> Mac mini worker claim/start/complete
  -> Collection result_json/model_name
  -> Platform meeting_analyses draft
  -> approval creates PMS task, decision, resource demand, risk, and knowledge records
```

End-to-end audio upload analysis flow verified:

```text
macOS test WAV
  -> Collection multipart upload with X-Upload-Token
  -> Collection audio asset storage under storage/audio
  -> Collection asset-based analysis job
  -> Mac mini worker claim/start
  -> Whisper.cpp STT
  -> Ollama LLM analysis
  -> Collection result_json/model_name
  -> Collection callback to Platform
  -> callback key id and signature verified
  -> Platform meeting_analyses draft
  -> unsigned callback rejected
  -> active/previous callback secrets are accepted during rotation
  -> completed job replay is idempotent
  -> failed callback retry/backoff is recoverable
  -> review edits can change/reject candidates before approval
  -> approval creates PMS task, decision, resource demand, risk, and knowledge records
  -> approved minutes can be previewed and distributed through dev-log delivery
  -> per-recipient delivery attempts are listed for Web review
  -> retryable delivery failures can be recovered manually or by retry-due worker
  -> resource profiles expose Resource Pool availability
  -> resource calendar blocks can make Resource Pool profiles unavailable
  -> resource demands can become assignment/reservation allocation records
  -> due unassigned resource demands can become idempotent risk candidates
  -> overlapping active allocations are retained as conflict records
  -> resource allocation conflicts can become idempotent risk candidates
  -> actual resource usage creates project cost candidates
  -> resource usage above allocation quantity can become idempotent risk candidates
  -> Web visual console shows Cost Feedback candidates
  -> over-threshold cost candidates can become idempotent risk candidates
  -> finance/PM review approves or rejects cost candidates before ERP settlement
  -> approved cost candidates can queue an external ERP handoff payload
  -> queued/due ERP handoffs can be sent through dev-log or HTTP connector mode
  -> failed handoff delivery can be retried by due worker
  -> ERP handoff responses reconcile to accepted/rejected/failed
  -> operations queue status summarizes email/ERP retry attention counts
  -> Web visual console can trigger due email retry and due ERP handoff send
  -> hourly LaunchAgent can run both operations recovery workers on Mac mini
  -> project knowledge items are searchable by Project_ID and kind
  -> project knowledge search can filter title/content/tags/evidence and expose evidence refs
  -> dashboard highlights overdue tasks, unresolved risks, resource conflicts, and distribution failures
  -> overdue tasks can be promoted into idempotent rule-based risk candidates
  -> over-threshold costs can be promoted into idempotent rule-based risk candidates
  -> unassigned resource demands can be promoted into idempotent rule-based risk candidates
  -> resource conflicts can be promoted into idempotent rule-based risk candidates
  -> resource usage overruns can be promoted into idempotent rule-based risk candidates
```

Integrated ERD structure:

```text
../개요/AI_PMS_ERD_구조.md
../개요/diagrams/19_ai_pms_integrated_erd.mmd
docs/21_erd_structure.md
```

ERD structure smoke:

```bash
bash scripts/smoke_erd_structure.sh
```

## Remaining First-MVP Integration Work

- run end-to-end recording/upload on a USB-connected physical Android device
- configure real SMTP provider credentials and load the recurring retry scheduler
- configure production ERP endpoint credentials and load the recurring handoff scheduler

## MVP Scope Definition Pass

The MVP requirements definition is now recorded as
`docs/23_mvp_requirements_definition.md`. It separates current implementation
and verification scope from future expansion scope, and fixes the product rule
that the recording flow selects only a project.

The formal submission document is generated from the same requirement source:

```bash
python3 scripts/export_formal_requirements_definition.py
bash scripts/smoke_formal_requirements_definition.sh
```

Generated outputs:

- `docs/23_mvp_requirements_definition.md`
- `../2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md`
- `../2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx`

The DOCX render check produced 15 pages and verifies the corrected document
structure: user roles in section 2.3, system administrator requirements in
section 3.3, functional requirements in section 4, and the traceability matrix
in section 8.3.

Scope corrections:

- attendee selection is not required in the active app upload flow
- Android packaged client keeps project selection and Meeting ID as the only
  recording context; attendee-save DTOs and `/attendees` calls are excluded
- speaker mapping and speaker/responsibility inference are excluded from MVP
- project-member automatic distribution remains the MVP delivery rule
- external recipients, full document management, notification center,
  advanced task board, resource/cost dashboards, and user groups are extension
  backlog items
- analysis prompts and sample contracts now leave speaker/assignee fields null
  unless explicitly labelled in the source transcript

Verification:

```bash
bash scripts/smoke_mvp_scope_definition.sh
bash scripts/smoke_formal_requirements_definition.sh
```

## Public Requirements Handoff

The same formal requirements definition is published into the public handoff
surface so the execution hub, reviewer package, and Drive document stay aligned.

Publication commands:

```bash
bash scripts/publish_requirements_documents.sh
bash scripts/publish_public_review_package.sh
bash scripts/publish_public_execution_hub.sh
```

Public outputs:

- `web_client/public/requirements/AI-PMS-requirements-v0.2.docx`
- `web_client/public/requirements/AI-PMS-requirements-v0.2.md`
- `web_client/public/requirements/requirements.json`
- `web_client/public/run/execution.json` with `requirements_docx`,
  `requirements_markdown`, and `requirements_manifest`
- `web_client/public/handoff/public-review-package.json` with the same
  requirements metadata and scope controls

Verification:

```bash
bash scripts/smoke_requirements_publication.sh
bash scripts/doctor_public_handoff.sh
bash scripts/smoke_public_access.sh "$WEB_URL" "$PLATFORM_URL" "$COLLECTION_URL" "$ANALYSIS_URL"
```

`doctor_public_handoff.sh` is non-mutating. It writes
`runtime/public_handoff/latest_doctor.json` and
`runtime/public_handoff/latest_doctor.md`, then separates required local
handoff consistency failures from public tunnel/DNS/local-service warnings.

`smoke_public_access.sh` requires running Web, Platform, Collection, and
Analysis URLs. It resolves URLs from positional arguments first, then
`AIPMS_PUBLIC_*_URL` environment variables, then `runtime/tunnels/*.log`.
For local static validation without a live public URL, use:

```bash
bash scripts/verify_mvp_static.sh
```

When tunnel URLs are available, `verify_mvp_static.sh` also republishes the
public review package and execution hub after requirements publication so the
handoff JSON does not retain stale requirements hashes.

`scripts/refresh_public_handoff_bundle.sh` records stale tunnel failures in
`runtime/public_handoff/latest_refresh.json` by default. Use
`AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1 bash scripts/refresh_public_handoff_bundle.sh`
when the command must fail on public connectivity errors.

## Ninety-fifth Implemented Item: Android Recorder-First Simplification

The Android APK now uses a single recorder-first screen instead of separate
home/project/recording/status/account menus.

Implemented behavior:

- removed the side menu and screen navigation buttons from the active app UI
- moved `회의 녹음` to the top of the first screen
- kept only required controls: meeting title/ID, record, upload/status,
  project loading, login/logout, and server URLs
- removed visible explanatory guide cards, benchmark copy, process
  descriptions, and chip rows
- kept no-attendee-selection and project-only upload rules
- updated `scripts/smoke_screen_design_ui.sh` to fail if Android side-menu or
  explanation markers are reintroduced

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `bash scripts/build_android_debug.sh`
- `bash scripts/verify_mvp_static.sh`

## Ninety-sixth Implemented Item: Drive Screen-Design UI Alignment

The current MVP UI now follows the Google Drive screen-design images more
closely while preserving the corrected recorder-first Android scope.

Implemented behavior:

- Android `MainActivity` uses a MEETFLOW-styled single screen with the meeting
  recording card first, project selection second, and account controls below
- Android visual styling now follows APP-04/APP-05: navy title, teal brand
  mark, bordered cards, large recording state, and waveform-style display
- React Web uses MEETFLOW branding in the sidebar and app-flow preview
- React Web first viewport was visually aligned to WEB-01/WEB-02 with KPI
  cards, recent meeting/decision panels, urgent work, kanban, project status,
  document space, app preview, review, and admin blocks
- English placeholder text in the app preview was replaced with Korean labels
  matching the Drive screen-design images
- a Playwright screenshot was saved at
  `output/playwright/drive-screen-design-web.png`

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `cd web_client && npm run build`
- `AIPMS_PLATFORM_BASE_URL=http://10.0.2.2:8000 AIPMS_COLLECTION_BASE_URL=http://10.0.2.2:8200 ANDROID_CLEAN_BUILD=1 AIPMS_ANDROID_TEMP_BUILD=1 bash scripts/build_android_public_debug.sh`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/verify_mvp_static.sh`

## Ninety-seventh Implemented Item: Canva Screen-Design Fixed Handoff

The screen-design output is now fixed into a Canva-import-ready PPTX because
the Canva connector returned `quota_exceeded` during direct generation.

Implemented behavior:

- generated `outputs/AI-PMS_MEETFLOW_screen_design_fixed.pptx`
- embedded the Google Drive screen-design reference images into a 12-slide
  MEETFLOW screen-design deck
- added slide-level rules for APP-01, APP-02, APP-04, APP-05, WEB-01, WEB-02,
  WEB-03, and ADMIN-01
- documented the implementation override that meeting context is project-only
  even if older source images still imply attendee selection
- added a fixed handoff document and public handoff JSON for review/package
  linkage
- exported PNG previews and layout JSON for every generated slide

Verification target:

- `node build-ai-pms-screen-design-fixed.mjs`
- rendered preview inspection for slides 03, 06, 08, and 12
- final PPTX file exists at `outputs/AI-PMS_MEETFLOW_screen_design_fixed.pptx`

## Ninety-eighth Implemented Item: Canva Fixed Handoff Smoke Gate

The Canva screen-design fixed output is now part of the static verification
loop so the PPTX and its handoff metadata do not drift silently.

Implemented behavior:

- added `scripts/smoke_canva_screen_design_fixed.sh`
- validates the fixed PPTX as a readable PowerPoint zip with 12 slides
- validates embedded media, manifest JSON, public handoff JSON, preview PNGs,
  and layout JSON files
- checks that the fixed rules still include recording-first app flow,
  project-only meeting context, automatic project-member distribution, and no
  AI speaker/owner inference
- wired the smoke into `scripts/verify_mvp_static.sh`

Verification target:

- `bash scripts/smoke_canva_screen_design_fixed.sh`
- `bash -n scripts/verify_mvp_static.sh`

## Ninety-ninth Implemented Item: User-Facing Copy Guard

The app and Web handoff pages now have a static guard that prevents
implementation, server, command, and prompt copy from leaking into user-facing
screens.

Implemented behavior:

- added `scripts/smoke_user_facing_copy_guard.sh`
- verifies Android does not attach internal connection/request fields to the UI
- scans Android visible labels, buttons, status text, and input hints for
  forbidden implementation terms
- scans public Web HTML visible text while ignoring CSS, scripts, and link URLs
- wires the guard into `scripts/smoke_screen_design_ui.sh` and
  `scripts/verify_mvp_static.sh`

Verification target:

- `bash scripts/smoke_user_facing_copy_guard.sh`
- `bash scripts/smoke_screen_design_ui.sh`

## One Hundredth Implemented Item: Local Environment Doctor

Local execution readiness now has a non-mutating doctor command that reports
required files, Python virtual environments, APK handoff integrity, generated
cache drift, and Web dependency readiness before running heavier verification.

Implemented behavior:

- added `scripts/doctor_local_environment.sh`
- added `scripts/smoke_local_environment_doctor.sh`
- writes `runtime/local_environment/latest_doctor.json` and
  `runtime/local_environment/latest_doctor.md`
- treats missing Web Vite dependencies as a warning with an explicit recovery
  recommendation, while APK hash or required service-directory failures remain
  required failures
- wired the smoke into `scripts/verify_mvp_static.sh`
- README now calls the local doctor before full static verification

Verification target:

- `bash scripts/doctor_local_environment.sh`
- `bash scripts/smoke_local_environment_doctor.sh`

## One Hundred First Implemented Item: Drive-Safe Web Dependency Repair

The Web build dependency recovery path now avoids repeated `node_modules`
corruption inside Google Drive by installing dependencies in an external cache
and linking `web_client/node_modules` to that cache.

Implemented behavior:

- added `scripts/repair_web_dependencies.sh`
- default cache path is `~/.cache/ai-pms/web_client`
- existing broken `web_client/node_modules` folders are moved to
  `.node_modules_broken_<timestamp>`
- local doctor now recommends the repair script when Vite is missing, not
  executable, or empty
- static verification checks that the repair script is present and documented

Verification target:

- `bash scripts/repair_web_dependencies.sh`
- `cd web_client && npm run build`
- `bash scripts/smoke_local_environment_doctor.sh`

## One Hundred Second Implemented Item: Collection API Public Binding Guard

Collection API is now guarded for external-network use. The upload service no
longer binds to every network interface by default; external Android access
should go through VPN or a tunnel that forwards to local `127.0.0.1:8200`.

Implemented behavior:

- `scripts/run_collection_api.sh` defaults to `127.0.0.1:8200`
- `scripts/windows_run_collection_api.ps1` defaults to `127.0.0.1:8200`
- direct `0.0.0.0` or `::` binding is rejected unless
  `AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1` is explicitly set
- added `scripts/smoke_collection_public_binding_guard.sh`
- static verification now fails if Collection API is currently listening on
  `*:8200`
- documented the required production-secret rotation before external sharing

Verification target:

- `bash scripts/smoke_collection_public_binding_guard.sh`
- `curl -i http://127.0.0.1:8200/upload-sessions`

## One Hundred Fourth Implemented Item: Platform And Analysis Public Binding Guard

Platform API and the Mac mini Analysis server now follow the same external
network policy as Collection API. Raw service ports stay local by default, and
external access should be routed through VPN or an authenticated tunnel.

Implemented behavior:

- `scripts/run_platform_backend.sh` defaults to `127.0.0.1:8000`
- `scripts/run_analysis_server.sh` defaults to `127.0.0.1:8100`
- Windows run scripts use the same local defaults
- direct `0.0.0.0` or `::` binding is rejected unless
  `AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1` or
  `AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND=1` is explicitly set
- added `scripts/smoke_core_api_public_binding_guard.sh`
- continuous acceptance now treats raw public binding on `8000` or `8100` as a
  required failure

Verification target:

- `bash scripts/smoke_core_api_public_binding_guard.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Third Implemented Item: Continuous Acceptance Check

External-operation readiness now has a single ongoing acceptance command for
hourly or manual 검수. It focuses on live safety checks instead of rebuilding
the whole project.

Implemented behavior:

- added `scripts/run_continuous_acceptance_check.sh`
- writes `runtime/continuous_acceptance/latest_report.json` and
  `runtime/continuous_acceptance/latest_report.md`
- verifies Collection API is not raw-public on `8200`
- verifies Platform and Analysis raw API ports are not public-bound
- verifies unauthenticated Collection upload creation returns `401` locally and
  through the current public tunnel
- verifies wrong internal secret returns `403`
- verifies the valid internal secret can read Collection job state without
  creating data
- verifies callback/internal secrets are non-default and aligned across
  Platform, Collection, and Analysis
- static verification now checks that the ongoing acceptance command exists and
  is documented

Verification target:

- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Fifth Implemented Item: Web Public Binding Guard

The Web client raw port now follows the external-network control policy used by
Platform, Collection, and Analysis. The dev server stays local by default while
public use goes through a tunnel.

Implemented behavior:

- local execution starts Web on `127.0.0.1:3000`
- public tunnel startup also runs Web on `127.0.0.1:3000`
- Windows Web scripts use the same default
- `npm run dev` and `npm run preview` no longer bind to `0.0.0.0`
- Vite is executed through the Node entrypoint to avoid executable-bit drift
  under Google Drive synced folders
- direct `0.0.0.0` or `::` binding is rejected unless
  `AIPMS_WEB_BIND_HOST=0.0.0.0` and `AIPMS_WEB_ALLOW_PUBLIC_BIND=1` are both set
- `scripts/smoke_web_public_binding_guard.sh` checks scripts, docs, and the
  live `3000` listener
- continuous acceptance treats raw public Web binding as a required failure

Verification target:

- `bash scripts/smoke_web_public_binding_guard.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Sixth Implemented Item: APK Publication Freshness Guard

APK publication freshness is now part of the ongoing acceptance loop. The guard
prevents a rebuilt Android app from diverging from the Web download package,
Drive direct handoff package, and evidence metadata.

Implemented behavior:

- `scripts/smoke_apk_publication_freshness.sh` compares the artifact APK, Web
  long-name APK, Web alias APK, and direct Drive APK
- metadata checks cover `android-apk.json`, `apk_manifest.json`,
  `AI-PMS-Recorder.sha256`, install check JSON/report, execution hub JSON,
  public review package JSON, and portfolio evidence JSON
- `scripts/run_continuous_acceptance_check.sh` now fails required acceptance if
  the public APK handoff is stale

Verification target:

- `bash scripts/smoke_apk_publication_freshness.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Ninth Implemented Item: Google Drive-Safe Verification Loop

The MVP verification loop now tolerates Google Drive offline placeholder files
and unstable Drive-hosted `node_modules` entries without weakening the required
acceptance checks.

Implemented behavior:

- `scripts/verify_mvp_static.sh` skips Python source files that are detected as
  Google Drive offline placeholders before attempting to read them
- Platform OpenAPI validation falls back to the live local `/openapi.json`
  endpoint when direct app import blocks on Drive placeholder files
- direct `rg` checks no longer read the offline `backend/app/routers/meetings.py`
  placeholder
- added `scripts/build_web_client_static.sh` to build the Web client from a
  temporary local directory using the cached Web dependencies
- `scripts/doctor_local_environment.sh` avoids direct `node_modules/.bin/vite`
  symlink stat calls under Google Drive and leaves Vite validation to the Web
  build script

Verification target:

- `bash scripts/smoke_local_environment_doctor.sh`
- `bash scripts/build_web_client_static.sh`
- `bash scripts/verify_mvp_static.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Tenth Implemented Item: Local Environment Doctor Cleanup

The local environment doctor now reports the current Drive-safe Web dependency
setup accurately and does not raise cleanup-only warnings for runtime-generated
Python caches.

Implemented behavior:

- `scripts/doctor_local_environment.sh` validates cached Vite under
  `$HOME/.cache/ai-pms/web_client` instead of probing Drive-hosted
  `web_client/node_modules`
- the doctor now requires `scripts/build_web_client_static.sh` as the Web build
  verification entrypoint
- generated `__pycache__` directories are treated as runtime cache output
- `scripts/.DS_Store` was removed from the working tree

Verification target:

- `bash scripts/smoke_local_environment_doctor.sh`
- `bash scripts/verify_mvp_static.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Eleventh Implemented Item: Placeholder-Aware Scope Smoke

The MVP scope smoke now fails fast with a clear message when a Google Drive
source file is offline instead of hanging on `grep`.

Implemented behavior:

- added `scripts/check_text_marker.py` for literal present/absent text checks
- the checker detects Drive offline placeholders by `st_blocks == 0` before
  attempting to read file content
- `scripts/smoke_mvp_scope_definition.sh` now uses the checker for MVP marker
  assertions and forbidden wording guards

Verification target:

- `python3 scripts/check_text_marker.py present android_client/src/main/java/com/aipms/MainActivity.kt 'recordButton = button("녹음 시작")' 'recorder-first Android primary action'`
- `bash scripts/smoke_mvp_scope_definition.sh`
- `bash scripts/verify_mvp_static.sh`

## One Hundred Twelfth Implemented Item: Pycache-Safe Static Syntax Scan

The static verification Python syntax scan now avoids runtime cache directories
before descending into the source tree, preventing Google Drive directory reads
from blocking on `__pycache__`.

Implemented behavior:

- replaced `Path.rglob("*.py")` with `os.walk` in
  `scripts/verify_mvp_static.sh`
- skipped `__pycache__`, `.mypy_cache`, `.pytest_cache`, and `.ruff_cache`
  directories before traversal
- kept offline placeholder file detection for actual Python source files

Verification target:

- inline Python syntax-scan check
- `bash scripts/verify_mvp_static.sh`

## One Hundred Seventh Implemented Item: Android Recorder UI Copy And Dead-Click Cleanup

The Android Compose UI now removes remaining non-MVP profile/settings rows and
technical wording from the app surface. The home actions no longer use empty
click handlers.

Implemented behavior:

- profile screen now keeps only the user card and logout action
- home hero copy is reduced to meeting recording
- quick action cards no longer show helper descriptions
- `새 녹음` calls the recording handler
- `파일 업로드` navigates to the meeting list surface
- Compose deprecation warnings in `AppComposeUI.kt` were reduced by switching
  to AutoMirrored icons, `HorizontalDivider`, and the enabled border API
- the public APK handoff was rebuilt and republished from the updated Android
  source

Current public APK SHA256:

- `85c6e0e2f47de8ad37750797fcb40b5cdaa532630bf4a4d1c6f394eb3cbcb59c`

Verification target:

- `bash scripts/smoke_user_facing_copy_guard.sh`
- `bash scripts/build_android_debug.sh`
- `AIPMS_REFRESH_BUILD_APK=1 AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1 bash scripts/refresh_public_handoff_bundle.sh`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/smoke_apk_publication_freshness.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Eighth Implemented Item: Android File Picker Modernization

The Android manual audio-file upload fallback now uses the Activity Result API
instead of deprecated request-code callbacks.

Implemented behavior:

- replaced `startActivityForResult`/`onActivityResult` with
  `ActivityResultContracts.GetContent`
- moved selected audio URI processing into `handleExternalAudioUri`
- removed the unused external audio request-code constant
- renamed legacy helper functions that conflicted with Kotlin-generated
  property setters
- updated Android build and APK publish scripts to copy APK files via a
  temporary destination before moving them into place under Google Drive
- rebuilt and republished the public APK handoff

Current public APK SHA256:

- `bf9ac62fbb7a8b6935b6e8542daaf6f1b34838301ec0ff1089a65028888567a0`

Verification target:

- `bash scripts/smoke_user_facing_copy_guard.sh`
- `bash scripts/build_android_debug.sh`
- `AIPMS_REFRESH_BUILD_APK=1 AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1 bash scripts/refresh_public_handoff_bundle.sh`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/smoke_portfolio_evidence_bundle.sh`
- `bash scripts/smoke_apk_publication_freshness.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Thirteenth Implemented Item: Android Local Build Warning Cleanup

The Android build environment now uses the Mac mini SDK path directly and no
longer keeps large generated JVM heap dumps inside the Google Drive project
folder.

Implemented behavior:

- corrected `android_client/local.properties` from a stale Windows Android SDK
  path to `/opt/homebrew/share/android-commandlinetools`
- removed generated `java_pid*.hprof` heap dump files from `android_client`
- removed generated `.DS_Store` metadata from the project root and
  `android_client`
- removed low-risk deprecated Android Gradle flags that were not required for
  the current debug APK build
- kept the Kotlin built-in migration warnings as an explicit follow-up item
  because removing `android.builtInKotlin=false` and `android.newDsl=false`
  requires a separate AGP 9 migration pass

Verification target:

- `bash -n scripts/build_android_debug.sh scripts/verify_mvp_static.sh scripts/run_continuous_acceptance_check.sh`
- `bash scripts/build_android_debug.sh`
- `bash scripts/smoke_local_environment_doctor.sh`
- `bash scripts/verify_mvp_static.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Fourteenth Implemented Item: Android Dependency Constraint Warning Cleanup

The Android debug build no longer emits the repeated dependency constraints
import-performance warning from AGP 9.

Implemented behavior:

- changed `android.dependency.useConstraints` to `false` in
  `android_client/gradle.properties`
- avoided the deprecated
  `android.dependency.excludeLibraryComponentsFromConstraints=true` setting
  after the build log identified it as deprecated
- confirmed that the debug APK still builds successfully with the updated
  dependency constraint setting
- kept the remaining AGP 9 Kotlin built-in and legacy Variant API warnings as
  a separate migration item

Verification target:

- `bash scripts/build_android_debug.sh`
- `bash scripts/verify_mvp_static.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Fifteenth Implemented Item: Android AGP 9 Kotlin Built-In Migration

The Android debug build now uses AGP 9 built-in Kotlin support and no longer
depends on the deprecated standalone `org.jetbrains.kotlin.android` plugin.

Implemented behavior:

- validated the migration first in a temporary Android project copy
- removed the standalone `org.jetbrains.kotlin.android` plugin from
  `android_client/build.gradle.kts`
- removed `android.builtInKotlin=false` and `android.newDsl=false` from
  `android_client/gradle.properties`
- eliminated the AGP 9 Kotlin built-in deprecation warning
- eliminated the legacy `applicationVariants`, `testVariants`, and
  `unitTestVariants` warnings during debug APK build
- kept `android.overridePathCheck=true` because the project is built from a
  Google Drive path and this remains a controlled local path override

Verification target:

- temporary AGP 9 migration probe build
- `bash scripts/build_android_debug.sh`
- `bash scripts/verify_mvp_static.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Sixteenth Implemented Item: Public External Flow Verification

The external-network flow is now verified end to end across the Android entry
contract, Collection API, Mac mini Analysis Worker, Platform API, and Web/App
review surfaces.

Implemented behavior:

- added `scripts/smoke_public_external_flow.sh` to log in through the public
  Platform API, create a project and meeting, upload an audio asset through the
  public Collection API, create an analysis job, wait for Worker completion,
  verify Platform callback success, and confirm the Web review package data
- decoupled Collection API job completion from the Platform callback by moving
  the callback notification to a FastAPI background task
- made the Analysis Worker Collection API request timeout configurable through
  `COLLECTION_REQUEST_TIMEOUT_SECONDS`
- changed the public Web tunnel startup to run Vite from a `/tmp` runtime copy
  with cached `node_modules`, avoiding Google Drive file-watcher stalls
- regenerated the public APK, installation dry-run report, and portfolio
  evidence summary so every published APK hash matches the current artifact
- confirmed raw service ports stay bound to `127.0.0.1` while public access is
  provided through Cloudflare tunnel URLs

Verification target:

- `AIPMS_REFRESH_BUILD_APK=1 AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1 bash scripts/refresh_public_handoff_bundle.sh`
- `bash scripts/smoke_public_external_flow.sh`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/export_portfolio_evidence_bundle.sh`
- `bash scripts/smoke_apk_publication_freshness.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Seventeenth Implemented Item: Continuous External Flow Evidence Gate

The continuous acceptance check now validates the latest public E2E evidence
instead of only checking public health endpoints.

Implemented behavior:

- `scripts/run_continuous_acceptance_check.sh` reads
  `runtime/public_handoff/latest_external_flow_check.json`
- the gate verifies that the latest public flow completed, Platform callback
  succeeded, the meeting is in `review_required`, and review data counts are
  present
- the gate compares the Web, Platform, Collection, and Analysis URLs in the
  latest E2E evidence against the currently active tunnel URLs
- `AIPMS_CONTINUOUS_REQUIRE_EXTERNAL_FLOW=0` can downgrade this check to a
  warning for local-only maintenance runs

Verification target:

- `bash -n scripts/run_continuous_acceptance_check.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Eighteenth Implemented Item: Analysis Server Direct 8100 Inbound Runtime

The Mac mini Analysis Server can now be intentionally run on direct inbound
port `8100` while keeping the default run-script policy guarded.

Implemented behavior:

- configured `analysis_server/.env` with `AIPMS_ANALYSIS_BIND_HOST=0.0.0.0`,
  `AIPMS_ANALYSIS_PORT=8100`, and `AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND=1`
- added the analysis bind settings to `analysis_server/app/core/config.py` so
  Pydantic accepts the runtime `.env` keys
- restarted the Analysis Server screen session and confirmed it listens on
  `*:8100`
- allowed the active Homebrew Python executable in macOS Application Firewall
- updated `scripts/smoke_core_api_public_binding_guard.sh` so explicit
  Analysis public binding is accepted only when the runtime allow flag is set

Verification target:

- `python3 -m py_compile analysis_server/app/core/config.py`
- `curl http://127.0.0.1:8100/health`
- `curl http://192.168.219.103:8100/health`
- `/usr/libexec/ApplicationFirewall/socketfilterfw --getappblocked /opt/homebrew/Cellar/python@3.12/3.12.13_4/Frameworks/Python.framework/Versions/3.12/Resources/Python.app/Contents/MacOS/Python`
- `bash scripts/smoke_core_api_public_binding_guard.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Nineteenth Implemented Item: Public Runtime Watchdog LaunchAgent

Public runtime can now be rechecked every 300 seconds by macOS launchd.

Implemented behavior:

- added `scripts/public_runtime_watchdog.sh` to check local Web/API health,
  public Web/API/APK URLs, and write
  `~/.aipms/public-runtime-state/runtime/always_on/latest_public_runtime.json`
- added `scripts/install_launchd_public_runtime.sh` to install
  `com.aipms.public-runtime`
- launchd logs now write to `~/.aipms/public-runtime-state/logs` instead of the
  Google Drive workspace to avoid macOS LaunchAgent write-permission failures
- the watchdog reuses the currently healthy quick tunnel URLs before attempting
  a new Cloudflare quick tunnel

Verification target:

- `bash scripts/install_launchd_public_runtime.sh --load`
- `launchctl print gui/$(id -u)/com.aipms.public-runtime`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Twentieth Implemented Item: Cross-Server Connectivity Doctor

Second-PC operation now has an explicit MVP-safe topology and verification
command.

Implemented behavior:

- updated `docs/29_analysis_failover_topology.md` so the second PC is treated as
  a secondary Collection/Analysis runtime, not a second Platform authority
- added `scripts/doctor_cross_server_connectivity.sh` for primary/secondary URL
  health checks
- the doctor defaults to the current public runtime URLs and supports
  `AIPMS_SECONDARY_HOST`, `AIPMS_SECONDARY_COLLECTION_URL`,
  `AIPMS_SECONDARY_ANALYSIS_URL`, and `AIPMS_EXPECT_SECONDARY`
- current primary Web, Platform, and Collection checks returned HTTP 200

Verification target:

- `bash -n scripts/doctor_cross_server_connectivity.sh`
- `bash scripts/doctor_cross_server_connectivity.sh`

## One Hundred Twenty-first Implemented Item: Cloudflare DNS Origin Doctor

Direct Cloudflare `A` record connection now has a readiness doctor and runbook.

Implemented behavior:

- added `scripts/doctor_cloudflare_dns_origin.sh` to report public IP, LAN IP,
  local Web/API health, local `80`/`443` origin listener state, and optional
  domain route status
- added `docs/30_cloudflare_dns_origin_runbook.md` with the DNS record table,
  router forwarding table, reverse proxy target map, and acceptance criteria
- current public IP and LAN IP are documented as observed values, not hard-coded
  runtime requirements

Verification target:

- `bash -n scripts/doctor_cloudflare_dns_origin.sh`
- `bash scripts/doctor_cloudflare_dns_origin.sh`

## One Hundred Twenty-second Implemented Item: Domainless GitHub Pages Web Deploy

The fixed-domain deployment path has been removed. The Web client now deploys
through the GitHub Pages default project URL, and API endpoints are injected by
deployment variables.

Implemented behavior:

- added `.github/workflows/deploy-web-pages.yml` for GitHub Pages deployment
- removed custom Web `CNAME` assumptions from the deployment path
- added `VITE_BASE_PATH` support in `web_client/vite.config.ts`
- updated `docs/19_cloudflare_named_tunnel_plan.md` to use variable-based API
  tunnel hostnames only
- added `docs/31_git_web_deploy_runbook.md` for GitHub Pages setup and local
  build verification

Verification target:

- `bash scripts/smoke_github_pages_cors.sh http://127.0.0.1:8000`
- `cd web_client && VITE_API_BASE=<platform-api-public-url> VITE_BASE_PATH=/llm-meeting-assistant/ npm run build`

## One Hundred Twenty-fourth Implemented Item: Mac mini Self-hosted Runner Deploy

The service stack can now be deployed from GitHub Actions through a Mac mini
self-hosted runner.

Implemented behavior:

- added `.github/workflows/deploy-mac-mini.yml`
- added `scripts/deploy_mac_mini_from_runner.sh`
- added `docs/32_self_hosted_runner_deploy_runbook.md`
- deployment syncs code into the configured runtime root and restarts Platform,
  Collection, Analysis, and Web without using broad `pkill`

Verification target:

- `bash -n scripts/deploy_mac_mini_from_runner.sh`
- `bash scripts/deploy_mac_mini_from_runner.sh --check`

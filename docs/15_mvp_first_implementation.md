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
  recording card first, project selection second, and account/server controls
  below
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

# Kim Heeseop Work Structure

Last updated: 2026-06-30

## Role Boundary

Drive collaboration guide defines Kim Heeseop's responsibility as Android,
React Web, Mac mini Analysis, integration design, JSON validation, and
documentation.

This role does not own Collection API implementation or Platform API business
implementation, but it owns the contracts that connect them:

- analysis JSON schema
- screen-to-API mapping
- worker status and retry state definitions
- integrated state transition map
- Project_ID-centered AI-PMS expansion structure
- evidence-based UX rules
- RBAC/ABAC and audit policy drafts

## Current Priority

The first implementation pass now covers the analysis contract, Collection API,
Mac mini worker loop, Web review flow, Android recording/upload client,
screen-design-based Web UI composition, direct APK package handoff, release
signing readiness, and portfolio evidence bundle.
The next priority is environment verification and production hardening.

| ID | Work | Priority | Local Output |
|---|---|---|---|
| BL-006 | Analysis JSON Schema draft | High | `contracts/analysis_result.schema.json` |
| BL-009 | Mac mini Worker state definition | High | `docs/06_platform_analysis_integration.md` |
| BL-018 | Integrated state transition table | High | `docs/01_architecture.md`, `docs/06_platform_analysis_integration.md` |
| BL-020 | Employee-number account policy | High | later auth policy/API |
| BL-025 | Project Core data model | High | later schema/API expansion |
| BL-028 | Action Item to Task policy | High | approval/task conversion logic |
| BL-038 | RBAC+ABAC policy | High | later permission and masking policy |
| BL-041 | Resource Demand/Assignment model | High | `backend/app/routers/resources.py`, `backend/migrations/0005_resource_allocation.sql` |

## Development Rule

Every Kim Heeseop-owned output should answer four questions:

1. Which screen uses it?
2. Which API consumes or produces it?
3. Which table or JSON contract stores it?
4. Which success and failure tests prove it?

## First Implemented Item: BL-006

The local scaffold now has an `analysis.v1` result contract.

Core fields:

- `schema_version`
- `language`
- `summary`
- `transcript_segments`
- `decisions`
- `action_items`
- `risks`
- `required_resources`
- `requires_human_approval`

Design intent:

- Mac mini Worker returns draft candidates only.
- Platform API validates and stores the result.
- React Web can render evidence-linked review screens.
- Approved action items can become PMS task candidates.
- Required resources can later become Resource Demand candidates.

## Second Implemented Item: BL-009 And BL-018

The local scaffold now has a shared status catalog.

Code-level constants:

- `backend/app/domain/statuses.py`
- `analysis_server/app/domain/statuses.py`

Contract and documentation:

- `contracts/status_catalog.json`
- `docs/10_state_transition_contract.md`

Current PoC behavior:

- Meeting analysis request moves the meeting to `analysis_queued`.
- Before calling the Mac mini Analysis Server, the job moves to `running` and
  the meeting moves to `analyzing`.
- Successful analysis moves the job to `completed` and the meeting to
  `review_required`.
- Approval moves the meeting to `approved`.

## Next Development Order

1. Install `AI-PMS-Recorder.apk` on a USB-connected physical Android device and
   run end-to-end recording/upload/status verification.
2. Configure real SMTP/ERP endpoint credentials and load the operations recovery
   LaunchAgent.
3. Add evidence-linked knowledge drill-down and later RAG/Q&A over the project knowledge index.

## Third Implemented Item: Web Review Package

The Platform API now exposes a review package for W-004 to W-006.

Endpoint:

- `GET /meetings/{meeting_id}/review-package`

Contract and documentation:

- `contracts/web_review_package.example.json`
- `docs/11_web_review_package_contract.md`

## Fourth Implemented Item: Action Item To Task Policy

The analysis contract and approval flow now keep conversion metadata when
approved action items create draft PMS tasks.

Code and schema:

- `analysis_result.schema.json`
- `backend/schema.sql`
- `backend/app/routers/approvals.py`
- `backend/app/schemas.py`
- `analysis_server/app/schemas.py`

Policy documentation:

- `docs/12_action_item_task_conversion_policy.md`

## Fifth Implemented Item: Required Resource To Resource Demand

Approval now stores AI-suggested required resources as Resource Demand
candidates.

Code and schema:

- `backend/schema.sql`
- `backend/app/routers/approvals.py`

Policy documentation:

- `docs/13_required_resource_demand_policy.md`

## Sixth Implemented Item: Collection API Scaffold

The local scaffold now includes `collection_api/`.

Responsibilities:

- upload sessions
- audio asset metadata
- collection analysis jobs
- worker heartbeat
- job claim/lease/retry
- job start/complete/fail status updates

Code and schema:

- `collection_api/app/routers/collection.py`
- `collection_api/app/domain/statuses.py`
- `collection_api/schema.sql`
- `scripts/run_collection_api.sh`
- `scripts/apply_collection_schema.sh`

Policy documentation:

- `docs/14_collection_api_scaffold.md`

## Seventh Implemented Item: First MVP Module Pass

The local scaffold now includes first-pass implementations across Platform,
Collection, Analysis Worker, React Web, and Android contract skeleton.

Documentation:

- `docs/15_mvp_first_implementation.md`

Verification:

- `scripts/verify_mvp_static.sh`

## Eighth Implemented Item: Platform To Collection Job Flow

Platform meeting analysis now creates a Collection transcript job instead of
calling the analysis server directly.

Implemented flow:

- Platform creates Collection upload session and analysis job.
- Mac mini Worker claims, starts, analyzes, and completes the job.
- Collection stores `model_name` and `result_json`.
- Platform polls the job, stores `meeting_analyses`, and approval reflects
  action items, decisions, resources, and risks into PMS records.

Code:

- `backend/app/services/collection_client.py`
- `backend/app/routers/meetings.py`
- `analysis_server/app/worker.py`
- `analysis_server/app/services/collection_client.py`
- `collection_api/app/routers/collection.py`

## Ninth Implemented Item: Android Audio Upload And Worker STT Flow

Collection API now accepts multipart audio uploads with `X-Upload-Token`, stores
audio under local `storage/audio`, registers an audio asset, and lets clients
create asset-based analysis jobs.

Mac mini Worker behavior:

- claims the Collection job
- fetches the audio asset
- runs Whisper.cpp STT
- runs Ollama analysis
- completes the Collection job with `model_name` and `result_json`

Code:

- `collection_api/app/routers/collection.py`
- `collection_api/app/schemas.py`
- `analysis_server/app/services/stt.py`
- `analysis_server/app/routers/stt.py`
- `analysis_server/app/worker.py`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsApiClient.kt`

## Tenth Implemented Item: Collection Completion Callback To Platform

Collection now notifies Platform when an analysis job completes. Platform stores
the result as a draft `meeting_analyses` row and moves the meeting to
`review_required`.

Implemented behavior:

- Collection `complete` stores `result_json` and `model_name`.
- Collection calls Platform callback.
- Platform stores a draft analysis with `source_collection_job_id` and
  `source_asset_id`.
- Duplicate callbacks are idempotent by `source_collection_job_id`.
- Approval reflects action items, decisions, resources, and risks into PMS
  records.

Code:

- `collection_api/app/routers/collection.py`
- `backend/app/routers/collection_callbacks.py`
- `backend/app/services/meeting_analysis_store.py`
- `backend/schema.sql`

## Eleventh Implemented Item: Signed Callback And Replay

Collection completion callbacks are now signed and replayable.

Implemented behavior:

- Collection signs callback payloads with HMAC-SHA256.
- Platform verifies timestamp and signature before accepting callbacks.
- Missing or invalid signatures are rejected.
- Collection exposes job event logs.
- Completed jobs can manually replay Platform notification.
- Replay is idempotent because Platform keys drafts by
  `source_collection_job_id`.

Code:

- `backend/app/routers/collection_callbacks.py`
- `backend/app/core/config.py`
- `collection_api/app/routers/collection.py`
- `collection_api/app/core/config.py`
- `scripts/smoke_audio_upload_job.sh`

## Twelfth Implemented Item: Automatic Callback Retry And Backoff

Collection now tracks Platform callback delivery state on each analysis job and
automatically retries due callbacks.

Implemented behavior:

- completed jobs initialize Platform callback state as `pending`
- each callback attempt records attempt count and last attempt time
- successful callbacks move to `succeeded`
- failed callbacks move to `retry_wait` with exponential backoff or `failed`
  after max attempts
- Collection exposes `POST /analysis-jobs/callbacks/retry-due`
- Collection starts a background retry loop with the API process
- smoke verification forces a retryable callback state and confirms recovery

Code:

- `collection_api/schema.sql`
- `collection_api/app/domain/statuses.py`
- `collection_api/app/core/config.py`
- `collection_api/app/main.py`
- `collection_api/app/routers/collection.py`
- `collection_api/app/schemas.py`
- `scripts/smoke_audio_upload_job.sh`

## Thirteenth Implemented Item: Web Review Edit Before Approval

React Web and Platform now support reviewer edits before approval.

Implemented behavior:

- Platform exposes `PUT /meetings/analyses/{analysis_id}/review-edits`
- reviewers can update the draft `analysis.v1` result before approval
- edits are blocked after approval or when the meeting is not `review_required`
- edit audit logs store before/after summary and candidate counts
- React Web can edit summary, action items, decisions, risks, and resources
- action items marked `rejected` are skipped during approval-to-task conversion
- smoke verification edits the draft, rejects action items, and confirms zero
  tasks are created on approval

Code:

- `backend/app/routers/meetings.py`
- `backend/app/routers/approvals.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_audio_upload_job.sh`

## Fourteenth Implemented Item: Android Native Recording Upload Client

Android now has a first native app pass for Kim Heeseop's collection module
scope inside the PMS.

Implemented behavior:

- plain Android Activity for project selection, recording, upload, and status
- runtime `RECORD_AUDIO` permission request
- `MediaRecorder` AAC/M4A recording into app cache
- Ktor Android client for Platform and Collection APIs
- upload session creation with file size and SHA-256 checksum metadata
- multipart audio upload with `X-Upload-Token`
- Collection analysis job creation
- polling until the analysis job reaches a terminal state
- emulator defaults use `10.0.2.2` for Mac mini localhost routing
- command-line Android build chain installed on the Mac mini
- Gradle wrapper and debug APK build verified

Code:

- `scripts/build_android_debug.sh`
- `android_client/settings.gradle.kts`
- `android_client/build.gradle.kts`
- `android_client/gradlew`
- `android_client/gradle/wrapper/gradle-wrapper.properties`
- `android_client/src/main/AndroidManifest.xml`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `android_client/src/main/java/com/aipms/recording/AndroidAudioRecorder.kt`
- `android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt`
- `android_client/src/main/java/com/aipms/client/MeetingUploadRepository.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/README.md`

Verification note:

- local static verification checks Android project structure and API usage
- `bash scripts/build_android_debug.sh` builds the debug APK successfully
- emulator verification is complete; physical device verification remains

## Fifteenth Implemented Item: Android Emulator Verification And M4A STT Support

The Android client has now been verified on a local API 35 ARM64 emulator.

Implemented and verified behavior:

- Android Emulator package and API 35 Google APIs ARM64 system image installed
- AVD `ai_pms_api35` created
- debug APK installed and `com.aipms/.MainActivity` launched
- app project refresh reached Platform API through `10.0.2.2:8000`
- emulator recording produced an Android `.m4a` asset
- Collection stored the uploaded asset and created an analysis job
- Mac mini Analysis Worker now converts Android `.m4a` to WAV with FFmpeg
  before Whisper
- replay job using the Android-uploaded asset completed with `qwen3:4b`
- Collection Platform callback finished with `platform_callback_status=succeeded`

Code and scripts:

- `scripts/run_android_emulator.sh`
- `scripts/install_android_debug.sh`
- `analysis_server/app/services/stt.py`
- `analysis_server/app/core/config.py`
- `analysis_server/.env.example`
- `android_client/src/main/java/com/aipms/MainActivity.kt`

## Sixteenth Implemented Item: Project Member Auto Distribution Baseline

Android A-002 is connected to Platform project members, but the current product
baseline is project selection only. The meeting recording flow does not ask the
user to manually select attendees; approved meeting content is distributed to
the selected project's members.

Implemented behavior:

- Android loads project members from `GET /projects/{project_id}/detail`
- Android renders project members as automatic distribution targets, not manual
  attendee checkboxes
- Android creates recording/upload sessions after project selection without a
  separate attendee-save step
- Platform email distribution derives recipients from active `project_members`
- the older meeting-attendee endpoints are not the primary recording flow
- emulator verification confirmed project-member lookup, audio upload,
  STT/LLM completion, and Platform callback success

Code and scripts:

- `backend/schema.sql`
- `backend/app/schemas.py`
- `backend/app/routers/meetings.py`
- `backend/app/routers/distributions.py`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsApiClient.kt`
- `android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt`
- `scripts/smoke_email_distribution.sh`

## Seventeenth Implemented Item: Managed Callback Secret Rotation

Collection-to-Platform callbacks now support key-id based HMAC rotation without
breaking in-flight retry/replay jobs.

Implemented behavior:

- Collection sends `X-Collection-Key-Id` with each signed callback
- Platform verifies the active key id and secret
- Platform can also accept configured previous key ids during a rotation window
- legacy callbacks without a key id are accepted only when their signature
  matches an active or previous secret
- unknown key ids and invalid signatures are rejected before callback storage
- smoke verification covers active, previous, legacy, unknown-key, and bad
  signature paths

Code and scripts:

- `backend/app/core/config.py`
- `backend/app/routers/collection_callbacks.py`
- `collection_api/app/core/config.py`
- `collection_api/app/routers/collection.py`
- `scripts/smoke_callback_secret_rotation.sh`
- `scripts/smoke_audio_upload_job.sh`

## Eighteenth Implemented Item: Bearer Access Token Verification

Platform login now issues verifiable bearer access tokens instead of demo
tokens.

Implemented behavior:

- login generates opaque `aipms_` bearer tokens
- only SHA-256 token hashes are stored in `access_tokens`
- token expiry is controlled by `ACCESS_TOKEN_TTL_SECONDS`
- `GET /users/me` verifies the bearer token and returns the current user
- `POST /users/logout` revokes the current token
- password change revokes active access tokens for that user
- smoke verification confirms bad login rejection, token verification, missing
  token rejection, logout, and revoked-token rejection

Code and scripts:

- `backend/schema.sql`
- `backend/app/core/config.py`
- `backend/app/services/auth_tokens.py`
- `backend/app/routers/users.py`
- `backend/app/schemas.py`
- `scripts/smoke_auth_tokens.sh`

## Nineteenth Implemented Item: React Web Bearer Login Flow

React Web now starts from the Drive-defined W-000 login flow and routes initial
password users to W-008 before opening the PMS review console.

Implemented behavior:

- Web login posts employee number and password to `POST /users/login`
- issued bearer token and user summary are stored in browser local storage
- app startup verifies stored tokens through `GET /users/me`
- Platform API calls include `Authorization: Bearer ...`
- users with `password_change_required` see the password-change screen
- password change re-logins with the new password after server-side token
  revocation
- logout calls `POST /users/logout` and clears local auth state
- browser verification confirmed login transitions to the password-change
  screen for an initial-password user

Code:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/verify_mvp_static.sh`

## Forty-fifth Implemented Item: Knowledge Search And Evidence Drill-Down

Project knowledge can now be searched by term and inspected with source
evidence directly from the visual console.

Implemented behavior:

- `GET /projects/{project_id}/knowledge-items` accepts `q` alongside
  `item_kind` and searches title, content, tags, and evidence JSON.
- React Web adds a Project Knowledge search input and submits the query to the
  Platform API.
- Knowledge rows can expand transcript evidence references, including speaker,
  segment, time range, and quote when available.
- Smoke verification covers search-only and kind-plus-search filtering.
- Static verification guards the query path and evidence UI classes.

Code:

- `backend/app/routers/projects.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_project_knowledge_index.sh`
- `scripts/verify_mvp_static.sh`

## Forty-sixth Implemented Item: Dashboard Attention KPIs

The dashboard now surfaces operational attention counts instead of only total
object counts.

Implemented behavior:

- `/dashboard/summary` exposes overdue tasks, unresolved risks, resource
  allocation conflicts, and failed/retry-wait email distributions.
- Project detail dashboard counts expose the same attention categories within
  one `Project_ID`.
- React Web top metrics include the four attention KPIs.
- React Web visual console adds an Attention KPI card for quick operational
  scanning.
- Smoke verification inserts deterministic overdue/risk/conflict/distribution
  data and checks both global and project-detail dashboards.

Code:

- `backend/app/routers/dashboard.py`
- `backend/app/routers/projects.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_dashboard_attention_kpis.sh`
- `scripts/verify_mvp_static.sh`

## Forty-seventh Implemented Item: Overdue Task Risk Promotion

Overdue tasks can now be promoted into rule-based project risk candidates so
`TASK_DELAYED` becomes an auditable PMS workflow event instead of only a
dashboard number.

Implemented behavior:

- `POST /tasks/overdue-risks` scans overdue non-closed tasks and creates
  `risks.status = candidate` rows.
- Risk evidence stores a deterministic `source_type = task_delay` and
  `task_id` marker for traceability and idempotency.
- Re-running the promotion does not create duplicate risks for the same task.
- Each created risk writes an audit log entry.
- React Web Attention KPI includes a manual action button to run the promotion
  and refresh the dashboard.
- Smoke verification covers auth guard, creation, idempotency, project detail
  dashboard counts, JSON evidence marker, and audit logging.

Code:

- `backend/app/routers/tasks.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_overdue_task_risk_promotion.sh`
- `scripts/verify_mvp_static.sh`

## Forty-eighth Implemented Item: Cost Candidate Risk Promotion

Project cost candidates can now be promoted into rule-based risk candidates so
`COST_EXCEEDED` is connected to PMS risk management before ERP settlement.

Implemented behavior:

- `POST /resources/cost-candidates/overrun-risks` scans candidate/approved
  project cost rows above a threshold amount and currency.
- Only `admin`, `pm`, and `finance` roles can run the promotion.
- Risk evidence stores a deterministic `source_type = cost_threshold` and
  `cost_id` marker for traceability and idempotency.
- Re-running the promotion does not create duplicate risks for the same cost
  candidate.
- Each created risk writes an audit log entry.
- React Web Cost Feedback includes a manual action button to run the promotion
  and refresh the dashboard.
- Smoke verification covers auth guard, threshold/currency filtering,
  creation, idempotency, project detail dashboard counts, JSON evidence marker,
  and audit logging.

Code:

- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_cost_candidate_risk_promotion.sh`
- `scripts/verify_mvp_static.sh`

## Forty-ninth Implemented Item: Resource Conflict Risk Promotion

Resource allocation conflicts can now be promoted into rule-based project risk
candidates so APMS-FR-033 has an auditable PMS risk-management path.

Implemented behavior:

- `POST /resources/allocations/conflict-risks` scans
  `resource_allocations.status = conflict` rows.
- Only `admin`, `pm`, and `resource_manager` roles can run the promotion.
- Risk evidence stores a deterministic `source_type = resource_conflict` and
  `allocation_id` marker for traceability and idempotency.
- Re-running the promotion does not create duplicate risks for the same
  conflict allocation.
- Each created risk writes an audit log entry.
- React Web Resource Pool includes a manual action button to run the promotion
  and refresh the dashboard.
- Smoke verification covers auth guard, conflict creation through allocation
  API, idempotency, project detail dashboard counts, JSON evidence marker, and
  audit logging.

Code:

- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_resource_conflict_risk_promotion.sh`
- `scripts/verify_mvp_static.sh`

## Fiftieth Implemented Item: Unassigned Resource Demand Risk Promotion

Candidate Resource Demands can now be promoted into rule-based project risk
candidates when their needed start date has arrived without assignment or
reservation.

Implemented behavior:

- `POST /resources/demands/unassigned-risks` scans
  `resource_demands.demand_status = candidate` rows whose `needed_from` is due.
- `due_within_days` supports near-term promotion while defaulting to already
  due demands only.
- Only `admin`, `pm`, and `resource_manager` roles can run the promotion.
- Risk evidence stores a deterministic `source_type = resource_unassigned` and
  `demand_id` marker for traceability and idempotency.
- Re-running the promotion does not create duplicate risks for the same demand.
- Each created risk writes an audit log entry.
- React Web Resource Pool includes a manual action button to run the promotion
  and refresh the dashboard.
- Smoke verification covers auth guard, candidate/future/assigned filtering,
  idempotency, project detail dashboard counts, JSON evidence marker, and audit
  logging.

Code:

- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_unassigned_resource_demand_risk_promotion.sh`
- `scripts/verify_mvp_static.sh`

## Fifty-first Implemented Item: Resource Usage Overrun Risk Promotion

Resource Usage entries can now be promoted into rule-based project risk
candidates when actual usage quantity exceeds the planned allocation quantity.

Implemented behavior:

- `POST /resources/usage/overrun-risks` scans resource usage rows joined to
  allocations with a planned quantity.
- `threshold_ratio` defaults to `1.0`, so usage greater than the allocation
  quantity is promoted.
- Only `admin`, `pm`, and `resource_manager` roles can run the promotion.
- Risk evidence stores a deterministic `source_type = resource_usage_overrun`
  and `usage_id` marker for traceability and idempotency.
- Re-running the promotion does not create duplicate risks for the same usage
  row.
- Each created risk writes an audit log entry.
- React Web Cost Feedback includes a manual action button to run the promotion
  and refresh the dashboard.
- Smoke verification covers auth guard, overrun/normal usage filtering,
  idempotency, project detail dashboard counts, JSON evidence marker, and audit
  logging.

Code:

- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_resource_usage_overrun_risk_promotion.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-second Implemented Item: Android Meeting Status Refresh

Android A-004 status tracking now has a Platform-backed status lookup.

Implemented behavior:

- Platform API exposes `GET /meetings/{meeting_id}/status`.
- The status response includes meeting status, progress, failure error code,
  latest analysis status, and latest distribution status.
- Android client contracts include `MeetingStatusDto`.
- Android UI has a `처리상태 확인` action that refreshes status by `Meeting_ID`.

Code:

- `backend/app/routers/meetings.py`
- `backend/app/schemas.py`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsApiClient.kt`
- `android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/verify_mvp_static.sh`

## Thirty-third Implemented Item: Resource Usage And Cost Candidate Feedback

The Resource Demand workflow now reaches the first usage/cost feedback step.

Implemented behavior:

- Platform stores actual resource usage in `resource_usage_entries`.
- Usage is recorded against a human-created `resource_allocations` row.
- Optional `cost_amount` creates a `project_cost_candidates` record.
- Conflict and cancelled allocations cannot record usage.
- Cost records remain AI-PMS candidates, preserving ERP/finance ledger
  boundaries.

Code and scripts:

- `backend/migrations/0007_resource_usage_cost.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/smoke_resource_usage_cost.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-fourth Implemented Item: Cost Feedback Visualization

The Web visual console now surfaces the resource usage and project cost feedback
created by the Resource Demand workflow.

Implemented behavior:

- Platform dashboard summary includes resource usage and candidate-cost counts.
- React Web loads `/resources/usage` and candidate `/resources/cost-candidates`.
- W-visual console shows a `Cost Feedback` card with usage-log count,
  candidate count, candidate total amount, and recent candidate rows.
- The operations pipeline includes a Cost step between Allocate and Distribute.

Code:

- `backend/app/routers/dashboard.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/verify_mvp_static.sh`

## Thirty-fifth Implemented Item: Cost Candidate Review Settlement Gate

Cost feedback now has a deterministic review gate before any finance/ERP
settlement boundary.

Implemented behavior:

- `project_cost_candidates` stores reviewer, review timestamp, and review note.
- Platform exposes `PATCH /resources/cost-candidates/{cost_id}/status`.
- Only `admin`, `pm`, and `finance` roles can approve or reject a cost
  candidate.
- Only `candidate` records can transition to `approved` or `rejected`.
- Every cost review writes an `audit_logs` record.
- React Web Cost Feedback rows expose icon actions for approve and reject.

Code:

- `backend/migrations/0008_cost_candidate_review.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_resource_usage_cost.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-sixth Implemented Item: Resource Capacity Calendar Blocks

Resource Pool availability now considers human-managed capacity calendar
blackout windows in addition to active allocation conflicts.

Implemented behavior:

- Platform stores `resource_calendar_blocks` per Resource Profile.
- `resource_manager`, `pm`, and `admin` can create calendar blocks.
- `GET /resources/profiles/{resource_id}/calendar-blocks` lists block history.
- `GET /resources/profiles/availability` returns
  `blocking_calendar_block_id` and marks blocked resources unavailable.
- React Web Resource Pool rows show `calendar block` when a calendar block is
  the availability blocker.
- Smoke coverage verifies role rejection, invalid windows, in-window blocking,
  and out-of-window availability recovery.

Code:

- `backend/migrations/0009_resource_calendar_blocks.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_resource_calendar_blocks.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-seventh Implemented Item: Approved Cost ERP Handoff Queue

Approved project cost candidates now have a safe external ERP handoff queue.

Implemented behavior:

- Platform stores `project_cost_handoffs` with target system, payload, status,
  external reference, requester, and timestamps.
- `POST /resources/cost-candidates/{cost_id}/erp-handoff` queues an approved
  cost candidate for external ERP/finance handoff.
- `GET /resources/cost-handoffs` lists queued or historical handoffs.
- Only `admin` and `finance` roles can create handoffs.
- Only `approved` cost candidates can be handed off.
- Handoff creation is idempotent per `cost_id` and `target_system`.
- The payload explicitly marks the ledger boundary as
  `external_erp_reference_only`.

Code:

- `backend/migrations/0010_project_cost_handoff.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/smoke_resource_usage_cost.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-eighth Implemented Item: ERP Handoff Reconciliation

Queued ERP cost handoffs can now be reconciled with an external response while
preserving the ERP finance ledger boundary.

Implemented behavior:

- `project_cost_handoffs` stores response payload, response note, and response
  receiver.
- `PATCH /resources/cost-handoffs/{handoff_id}/status` transitions queued
  handoffs to `accepted`, `rejected`, or `failed`.
- Only `admin` and `finance` roles can reconcile handoffs.
- Completed handoffs cannot be changed again.
- Every reconciliation writes an `audit_logs` record.
- Smoke coverage verifies accepted reconciliation, non-finance rejection, and
  duplicate reconciliation rejection.

Code:

- `backend/migrations/0011_project_cost_handoff_reconciliation.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/smoke_resource_usage_cost.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-ninth Implemented Item: ERP Handoff Delivery Worker

Approved cost handoffs now have an outbox-style delivery path before final ERP
reconciliation.

Implemented behavior:

- `project_cost_handoffs` stores delivery mode, attempt count, last error, next
  retry time, and last attempted time.
- `POST /resources/cost-handoffs/{handoff_id}/send` sends a queued or
  retry-wait handoff.
- `POST /resources/cost-handoffs/send-due` processes queued handoffs and due
  retry-wait handoffs.
- `scripts/run_erp_handoff_worker_once.sh` provides the same processing path for
  cron or launchd.
- Default `dev_log` mode records provider-style references without touching an
  external ledger.
- `http` mode posts the handoff payload to the configured ERP endpoint and
  stores provider response metadata.
- Successful delivery moves the handoff to `sent`, which still waits for
  explicit accepted/rejected/failed reconciliation.
- Failed delivery stores the provider error and schedules retry until max
  attempts are exhausted.

Code:

- `backend/migrations/0012_project_cost_handoff_delivery.sql`
- `backend/schema.sql`
- `backend/app/core/config.py`
- `backend/app/services/erp_handoff.py`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/run_erp_handoff_worker_once.sh`
- `scripts/smoke_erp_handoff_delivery.sh`
- `scripts/verify_mvp_static.sh`

## Fortieth Implemented Item: Operations Queue Status Visualization

Platform now exposes a lightweight operations queue status API and the Web
visual console shows email/ERP retry health.

Implemented behavior:

- `GET /operations/queue-status` summarizes retry/outbox state for
  `email_distributions` and `project_cost_handoffs`.
- The API reports status counts, due retry counts, attention counts, latest
  created time, next retry time, and the latest provider error.
- The route requires an active bearer token like the other user-facing Platform
  APIs.
- React Web visual console shows an `Operations Queue` card next to the existing
  project/meeting/resource/cost cards.
- Smoke coverage verifies unauthenticated rejection and deterministic email/ERP
  retry queue counts.

Code:

- `backend/app/routers/operations.py`
- `backend/app/main.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_operation_queue_status.sh`
- `scripts/verify_mvp_static.sh`

## Forty-first Implemented Item: Operations Queue Recovery Actions

The Web visual console now turns the operations queue status card into a small
recovery control surface for due email and ERP outbox work.

Implemented behavior:

- `Operations Queue` shows icon actions for due email retry and due ERP handoff
  sending next to the queue status counts.
- The email action calls `POST /distributions/retry-due` and refreshes dashboard
  and visual queue state after processing.
- The ERP action calls `POST /resources/cost-handoffs/send-due`, remains limited
  to `admin` and `finance` roles in the UI, and refreshes the same state.
- The operation queue smoke test now verifies both status visibility and the due
  processing endpoints used by the Web controls.
- Static verification guards the Web action functions, endpoint wiring, and CSS
  affordance.

Code:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_operation_queue_status.sh`
- `scripts/verify_mvp_static.sh`
- `README.md`
- `docs/08_drive_based_reconfiguration.md`
- `docs/15_mvp_first_implementation.md`

## Forty-second Implemented Item: Hourly Operations Recovery Scheduler

Mac mini operations recovery can now run as a single one-shot command or as an
hourly macOS LaunchAgent.

Implemented behavior:

- `scripts/run_operations_recovery_once.sh` runs the due email delivery retry
  worker and due ERP handoff worker in one operational command.
- `scripts/install_launchd_operations_recovery.sh` renders a LaunchAgent for
  hourly recovery with `StartInterval=3600`, `RunAtLoad=true`, and log files
  under `logs/`.
- The LaunchAgent script supports `--check`, `--install`, `--load`, `--unload`,
  and `--print`; the hourly job is not loaded unless `--load` is explicitly run.
- Environment variables can override the LaunchAgent label, interval, and batch
  limit without editing the plist.
- Static verification now guards the combined runner, LaunchAgent installer, and
  README/MVP documentation links.

Code:

- `scripts/run_operations_recovery_once.sh`
- `scripts/install_launchd_operations_recovery.sh`
- `scripts/verify_mvp_static.sh`
- `README.md`
- `docs/08_drive_based_reconfiguration.md`
- `docs/15_mvp_first_implementation.md`

## Twentieth Implemented Item: Android Bearer Login Flow

Android now has the same Platform bearer-auth foundation as React Web before
project selection and upload.

Implemented behavior:

- Android exposes employee-number/password login fields
- `POST /users/login` stores the issued bearer token in SharedPreferences
- app startup restores a saved token through `GET /users/me`
- Platform API calls send `Authorization: Bearer ...`
- users with `password_change_required` must complete the Android password
  change section before project lookup/upload
- password change calls `POST /users/password/change`, then re-logins with the
  new password because the server revokes active tokens
- logout calls `POST /users/logout`, clears the token, and resets local project
  and attendee state

Code:

- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/client/AiPmsApiClient.kt`
- `android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt`
- `scripts/verify_mvp_static.sh`

## Twenty-first Implemented Item: Platform Bearer API Guards

User-facing Platform API routes now require an active bearer token after the
initial password-change gate.

Implemented behavior:

- project, meeting, approval, dashboard, task, and resource routers require
  `Authorization: Bearer ...`
- missing or revoked bearer tokens return `401`
- users still in `PASSWORD_CHANGE_REQUIRED` can call `/users/me` but receive
  `403` from PMS business APIs
- Collection completion callbacks remain protected by signed callback headers,
  not user bearer tokens
- smoke verification covers missing auth, password-change-required auth, active
  token access, token revocation, project detail, dashboard, and attendee save

Code and scripts:

- `backend/app/services/auth_tokens.py`
- `backend/app/routers/projects.py`
- `backend/app/routers/meetings.py`
- `backend/app/routers/approvals.py`
- `backend/app/routers/dashboard.py`
- `backend/app/routers/tasks.py`
- `backend/app/routers/resources.py`
- `scripts/smoke_protected_platform_api.sh`
- `scripts/smoke_meeting_attendees.sh`
- `scripts/smoke_audio_upload_job.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-second Implemented Item: Admin-Only User Registration

The Platform API no longer exposes public user collection endpoints. User
creation now follows the Drive authentication policy: PMS/admin-managed account
registration only.

Implemented behavior:

- `POST /users` and `GET /users` collection routes are removed
- `POST /admin/users` creates employee-number users and requires an active
  admin bearer token
- `GET /admin/users` lists users and requires an active admin bearer token
- admin accounts still pass through the initial password-change gate before
  using admin APIs
- non-admin active users receive `403` on admin user-management APIs
- duplicate employee numbers return `409`
- local smoke/demo data uses a DB seed script instead of public API creation

Code and scripts:

- `backend/app/routers/admin_users.py`
- `backend/app/routers/users.py`
- `backend/app/main.py`
- `backend/app/services/auth_tokens.py`
- `backend/app/services/users.py`
- `scripts/seed_platform_user.py`
- `scripts/seed_demo_admin.sh`
- `scripts/smoke_demo_admin_credentials.sh`
- `scripts/smoke_admin_user_registration.sh`
- `scripts/smoke_auth_tokens.sh`
- `scripts/smoke_protected_platform_api.sh`
- `scripts/smoke_meeting_attendees.sh`
- `scripts/smoke_audio_upload_job.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-third Implemented Item: Android Physical LAN Build Kit

The Android client can now be built with Mac mini LAN endpoints for a physical
device, while the normal debug build keeps the emulator-friendly `10.0.2.2`
defaults.

Implemented behavior:

- Android `BuildConfig` carries default Platform and Collection base URLs
- emulator debug builds default to `http://10.0.2.2:8000` and
  `http://10.0.2.2:8200`
- physical-device LAN builds inject `http://<Mac-mini-LAN-IP>:8000` and
  `http://<Mac-mini-LAN-IP>:8200`
- a LAN smoke script checks Web, Platform health, and CORS before installing
  to a device
- the physical-device install script builds, installs, grants microphone
  permission, and launches the app when one USB device is connected

Code and scripts:

- `android_client/build.gradle.kts`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/build_android_lan_debug.sh`
- `scripts/install_android_physical_lan_debug.sh`
- `scripts/smoke_lan_access.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-fourth Implemented Item: Database Migration Runner

Platform API and Collection API now use service migrations instead of direct
`schema.sql` application.

Implemented behavior:

- Platform migrations live under `backend/migrations`
- Collection migrations live under `collection_api/migrations`
- `scripts/run_migrations.py` records applied migrations in
  `schema_migrations`
- migration checksums prevent silent edits to already-applied files
- `scripts/apply_platform_schema.sh` and
  `scripts/apply_collection_schema.sh` apply migrations through each service
  virtual environment
- `scripts/run_platform_backend.sh` and `scripts/run_collection_api.sh` inherit
  the migration path because they call the apply scripts
- Docker PostgreSQL init no longer mounts `backend/schema.sql` directly

Code and docs:

- `scripts/run_migrations.py`
- `backend/migrations/0001_platform_initial.sql`
- `collection_api/migrations/0001_collection_initial.sql`
- `scripts/apply_platform_schema.sh`
- `scripts/apply_collection_schema.sh`
- `docker-compose.yml`
- `docs/17_database_migration_policy.md`
- `scripts/verify_mvp_static.sh`

## Twenty-fifth Implemented Item: Admin User Management UI And Reset

React Web now implements W-007 for admin-managed user operations.

Implemented behavior:

- admin users can open a dedicated user-management tab
- admin users can create employee-number accounts from Web
- admin users can list existing users
- admin users can update name, email, role, and account status
- admin users can reset a user's password to an entered temporary value
- reset revokes the user's active bearer tokens
- reset moves the user back to `password_change_required` by default
- audit logs record create, update, and reset operations
- local demo administrator login is fixed to `admin / 1234` and seeded in
  `active` state for immediate Web/API access

Code and scripts:

- `backend/app/routers/admin_users.py`
- `backend/app/services/users.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/seed_demo_admin.sh`
- `scripts/smoke_demo_admin_credentials.sh`
- `scripts/smoke_admin_user_registration.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-sixth Implemented Item: Password Reset Request And Confirmation

React Web now implements W-009 and W-010 for self-service password reset.

Implemented behavior:

- users request reset with employee number and registered email
- Platform stores only a hash of the reset token
- reset tokens are one-time-use and expire
- local PoC returns a development token instead of sending email
- token verification confirms the target account before password change
- successful reset activates the account and revokes active bearer tokens
- reused or invalid tokens are rejected

Code and scripts:

- `backend/migrations/0002_password_reset_tokens.sql`
- `backend/app/services/password_resets.py`
- `backend/app/routers/users.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_password_reset.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-seventh Implemented Item: Email Distribution Preview And Delivery Log

React Web now implements W-006 for approved meeting-minutes distribution.

Implemented behavior:

- approved meetings expose a distribution preview only after analysis approval
- Platform generates subject, body, and default project-member recipients
- users can edit subject, body, and recipient rows before distribution
- distribution writes a `dev_log` delivery record instead of sending SMTP mail
- each recipient gets an auditable delivery attempt row
- duplicate distribution of the same approved analysis is rejected
- meeting status moves from `approved` to `distributed`

Code and scripts:

- `backend/migrations/0003_email_distributions.sql`
- `backend/app/routers/distributions.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_email_distribution.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-eighth Implemented Item: Email Delivery Retry Worker

Platform email distribution now has an SMTP-ready delivery path and retry
metadata.

Implemented behavior:

- distribution creation now writes a queued outbox row before delivery
- local `dev_log` mode still marks recipients as sent for offline PoC demos
- SMTP mode can be enabled with environment variables
- failed delivery attempts store provider errors and next retry time
- distribution status can move through `sending`, `sent`, `partial_failed`,
  `retry_wait`, and `failed`
- manual retry is available for failed distributions
- due retry processing is available through API and a one-shot worker script

Code and scripts:

- `backend/migrations/0004_email_delivery_retry.sql`
- `backend/app/services/email_delivery.py`
- `backend/app/routers/distributions.py`
- `backend/app/core/config.py`
- `scripts/run_email_delivery_worker_once.sh`
- `scripts/smoke_email_retry.sh`
- `scripts/verify_mvp_static.sh`

## Twenty-ninth Implemented Item: Resource Allocation And Conflict API

Resource Demand can now move into the first Resource Assignment/Reservation
workflow without letting LLM output allocate resources directly.

Implemented behavior:

- approved required-resource candidates still create `resource_demands`
- human/API action creates `resource_allocations` under a demand
- `allocation_type` distinguishes `assignment` and `reservation`
- demand status moves to `assigned`, `reserved`, or `conflict`
- duplicate active allocation windows for the same `resource_name` are retained
  as `conflict` records with `conflict_reason`
- allocation status can be changed to `proposed`, `confirmed`, `released`, or
  `cancelled`
- allocation create/update operations are audit logged

Code and scripts:

- `backend/migrations/0005_resource_allocation.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/smoke_resource_allocation.sh`
- `scripts/verify_mvp_static.sh`

## Thirtieth Implemented Item: Resource Profile And Availability API

Resource Pool profiles now sit in front of assignment/reservation so the PMS can
check availability before creating allocations.

Implemented behavior:

- resource managers can create Resource Pool profiles for people, rooms,
  vehicles, equipment, software, or other resources
- profiles keep capacity, unit, location, owner, status, and creator
- availability lookup reports whether a profile is blocked in a requested date
  window
- allocation creation can use `resource_id` and inherits profile name/type
- profile-backed allocations still produce `conflict` records for duplicate
  active windows
- profile creation is audit logged

Code and scripts:

- `backend/migrations/0006_resource_profiles.sql`
- `backend/schema.sql`
- `backend/app/routers/resources.py`
- `backend/app/schemas.py`
- `scripts/smoke_resource_profiles.sh`
- `scripts/verify_mvp_static.sh`

## Thirty-first Implemented Item: Recent Meeting Status Visualization

React Web now exposes a W-003-style recent meeting status panel inside the
visualization console.

Implemented behavior:

- Platform API lists recent meetings with project name and latest analysis
  status through `GET /meetings`.
- React Web visual console loads the recent meeting list with resource and
  dashboard data.
- Each recent meeting row shows processing state and can open the review view
  with the selected `Meeting_ID`.

Code:

- `backend/app/routers/meetings.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/verify_mvp_static.sh`

## Forty-third Implemented Item: Project Knowledge Index

Approved meeting analysis now writes project-scoped knowledge records so meeting
AI output is not limited to one review screen.

Implemented behavior:

- approval creates `project_knowledge_items` for summary, decisions, approved
  action items, risks, and required resources
- duplicate approval/retry paths are idempotent by source analysis, item kind,
  and source item index
- `GET /projects/{project_id}/knowledge-items` lists active knowledge records
  and can filter by `item_kind`
- project detail and dashboard summaries expose `knowledge_items` counts
- React Web shows the knowledge item KPI in the main visual console metrics
- smoke verification covers auth guard, approval count, kind filtering, project
  detail, and dashboard summary

Code and scripts:

- `backend/migrations/0013_project_knowledge_items.sql`
- `backend/schema.sql`
- `backend/app/services/knowledge_index.py`
- `backend/app/routers/approvals.py`
- `backend/app/routers/projects.py`
- `backend/app/routers/dashboard.py`
- `backend/app/schemas.py`
- `web_client/src/main.tsx`
- `scripts/smoke_project_knowledge_index.sh`
- `scripts/verify_mvp_static.sh`

## Forty-fourth Implemented Item: Web Project Knowledge Explorer

React Web now exposes the project knowledge index as a browsable visual-console
panel instead of only a dashboard count.

Implemented behavior:

- the visual console loads `GET /projects/{project_id}/knowledge-items`
  whenever the selected project or item kind changes
- users can switch project and filter by summary, decision, Action Item, risk,
  or required resource
- each knowledge row shows kind, title, content, source meeting, evidence count,
  tags, and created time
- empty state and manual refresh are handled without reloading unrelated visual
  console data
- static verification guards the Web API call, panel text, and responsive CSS

Code:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/verify_mvp_static.sh`

## Fifty-second Implemented Item: Part Handoff Drafts

The AI-PMS whole-flow logic and team handoff draft are now consolidated for
Collection API, Platform API, and Kim Heeseop-owned integration work.

Implemented behavior:

- documents the full Project_ID-centered flow from Android capture to PMS
  reflection, distribution, ERP handoff, and project knowledge indexing
- defines the review boundary for Collection API, Platform API, Android, Web,
  Mac mini Analysis, and integration documentation
- provides copy-ready draft messages for Kim Kanghyun, Park Jooyeon, and Kim
  Heeseop review checkpoints
- records current external tunnel URLs and public debug APK handoff notes as
  temporary review assets

Documentation:

- `docs/18_part_handoff_drafts.md`

## Fifty-third Implemented Item: Responsive Android APK Layout

The Android app now supports phone and tablet layouts through one APK.

Implemented behavior:

- phone-width screens keep the existing single-column recording/upload flow
- tablet-width screens (`screenWidthDp >= 600`) switch to a two-column layout:
  connection/account/meeting setup on the left and attendees/recording/status
  on the right
- action buttons become horizontal within tablet cards to reduce vertical
  scrolling
- the activity is marked resizeable so Android can adapt it across larger
  screens and windowed modes

Code and documentation:

- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `android_client/src/main/AndroidManifest.xml`
- `android_client/README.md`

## Fifty-fourth Implemented Item: Public Tunnel And APK Automation

Temporary public tunnel exposure and public Android APK handoff are now
reproducible through scripts instead of manual cloudflared commands.

Implemented behavior:

- `scripts/run_public_tunnels.sh` starts/reuses Cloudflare quick tunnels for
  Web, Platform API, Collection API, and Analysis Server
- existing quick tunnel sessions are reused only after the latest public URL
  passes a health check; stale sessions are restarted automatically
- the Web dev server can be restarted with `VITE_API_BASE` pointing at the
  active public Platform tunnel
- `scripts/print_public_urls.sh` prints the current tunnel URLs from
  `runtime/tunnels/*.log`
- `scripts/smoke_public_access.sh` verifies public Web/API health and Platform
  CORS from the public Web origin
- `scripts/build_android_public_debug.sh` builds the responsive public debug APK
  with the active Platform and Collection tunnel URLs injected
- `scripts/publish_android_apk_download.sh` publishes the APK into
  `web_client/public/downloads/` so the public Web tunnel can serve a download
  page, APK file, and JSON metadata

Operational control:

- set `AIPMS_PUBLIC_TUNNEL_REUSE_HEALTH_CHECK=0` only when stale quick tunnel
  reuse must be debugged manually

Code and documentation:

- `scripts/run_public_tunnels.sh`
- `scripts/print_public_urls.sh`
- `scripts/smoke_public_access.sh`
- `scripts/build_android_public_debug.sh`
- `scripts/publish_android_apk_download.sh`
- `web_client/public/downloads/index.html`
- `web_client/public/downloads/android-apk.json`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Fifty-fifth Implemented Item: Web APK Download Entry Point

The public Android APK download path is now discoverable from the Web console
instead of requiring users to know `/downloads/` manually.

Implemented behavior:

- the authenticated Web header includes an `APK 다운로드` link
- the link opens `/downloads/`, which serves the APK download page from
  `web_client/public/downloads/index.html`
- the existing public tunnel URL can now be shared as the main Web entry point,
  with APK access available from the same surface

Code and documentation:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `web_client/public/downloads/index.html`
- `scripts/verify_mvp_static.sh`

## Fifty-sixth Implemented Item: Public Part Handoff Page

The team handoff draft is now available as a public Web route instead of only a
repository Markdown file.

Implemented behavior:

- the authenticated Web header includes a `파트 전달안` link
- `/handoff/` serves a static team review page from
  `web_client/public/handoff/index.html`
- the React SPA fallback also renders public `/handoff/` and `/downloads/`
  views so Vite dev tunnel routes do not fall back to the login shell
- the page summarizes the Android -> Collection -> Worker -> Platform -> Web
  flow, external public URLs, APK details, reviewer ownership, response format,
  and next execution order
- static verification guards the route entry point and handoff content markers

Code and documentation:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `web_client/public/handoff/index.html`
- `scripts/verify_mvp_static.sh`

## Fifty-seventh Implemented Item: Cloudflare Named Tunnel Preparation

The fixed-domain external access path is now scaffolded as the next step after
temporary quick tunnels.

Implemented behavior:

- `scripts/prepare_cloudflare_named_tunnel.sh` writes a named tunnel example
  config and, when Cloudflare tunnel/hostname environment variables are
  present, writes `runtime/cloudflare_named_tunnel/config.yml`
- `scripts/run_cloudflare_named_tunnel.sh` checks local Web, Platform,
  Collection, and Analysis services before starting `cloudflared tunnel run`
  in a screen session
- `docs/19_cloudflare_named_tunnel_plan.md` records hostname mapping,
  environment variables, DNS route commands, run order, and Android public APK
  rebuild steps for fixed URLs
- README and handoff docs now point to the named tunnel preparation path

Code and documentation:

- `scripts/prepare_cloudflare_named_tunnel.sh`
- `scripts/run_cloudflare_named_tunnel.sh`
- `docs/19_cloudflare_named_tunnel_plan.md`
- `README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Fifty-eighth Implemented Item: Android Release Signing Preparation

The Android app now has a release-signing path for external distribution after
the current debug APK review stage.

Implemented behavior:

- Gradle can read release signing values from `AIPMS_RELEASE_*` environment
  variables or matching Gradle properties
- `scripts/prepare_android_release_signing.sh` writes a local release-signing
  env template and can optionally create a local JKS keystore when explicitly
  enabled
- `scripts/build_android_release_apk.sh` requires keystore credentials, injects
  Platform/Collection base URLs, builds `assembleRelease`, copies the APK to
  `artifacts/apk/AiPmsAndroidClient-responsive-release.apk`, and verifies with
  `apksigner` when available
- `docs/20_android_release_signing.md` records the release build procedure and
  distribution rule

Code and documentation:

- `android_client/build.gradle.kts`
- `scripts/prepare_android_release_signing.sh`
- `scripts/build_android_release_apk.sh`
- `docs/20_android_release_signing.md`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Fifty-ninth Implemented Item: Public Route Smoke Coverage

The external sharing smoke test now covers the Web surfaces that reviewers and
Android testers actually use, not only service health endpoints.

Implemented behavior:

- `scripts/smoke_public_access.sh` verifies the public download and handoff
  routes before links are sent to reviewers
- the smoke test validates `downloads/android-apk.json`, the responsive APK
  file name, and the `responsive_phone_tablet` build marker
- the APK file is downloaded through the public Web tunnel and checked for a
  minimum size so a broken or missing static asset fails the smoke run
- when Vite dev source is reachable, the smoke test also checks the SPA
  `PublicDownloadPage` and `PublicHandoffPage` route markers
- README, MVP, and handoff docs now state that public route, APK, API health,
  and CORS checks are part of the external sharing procedure

Code and documentation:

- `scripts/smoke_public_access.sh`
- `scripts/verify_mvp_static.sh`
- `README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixtieth Implemented Item: Public Review Package Manifest

The external handoff page now has a machine-readable review package for team
sharing and repeatable checks.

Implemented behavior:

- `scripts/publish_public_review_package.sh` reads active Cloudflare tunnel
  logs and `downloads/android-apk.json`
- the script writes `web_client/public/handoff/public-review-package.json` with
  Web/API URLs, APK download details, owner-specific review scopes, expected
  smoke statuses, and the required publish order
- the public handoff page links to the review package JSON for reviewers who
  need a copyable source of URLs and check items
- `scripts/smoke_public_access.sh` now verifies the review package route and
  markers before public links are considered shareable
- README, Android README, MVP, and handoff docs now place `smoke_public_access`
  after APK publish and review package publish

Code and documentation:

- `scripts/publish_public_review_package.sh`
- `web_client/public/handoff/public-review-package.json`
- `web_client/public/handoff/index.html`
- `scripts/smoke_public_access.sh`
- `scripts/verify_mvp_static.sh`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-first Implemented Item: Public Handoff Bundle Refresh

External sharing can now be refreshed through one non-destructive command.

Implemented behavior:

- `scripts/refresh_public_handoff_bundle.sh` prints current public tunnel URLs,
  republishes the existing responsive public APK into the Web download folder,
  regenerates the review package JSON, runs public smoke, and writes a local
  summary JSON under `runtime/public_handoff/latest_refresh.json`
- the script is non-disruptive by default and does not restart tunnels or
  rebuild the APK
- `AIPMS_REFRESH_START_TUNNELS=1` can include tunnel startup when needed
- `AIPMS_REFRESH_BUILD_APK=1` can rebuild the APK against the current public
  Platform/Collection tunnel URLs before publishing
- README, Android README, MVP, and handoff docs now reference the refresh
  command as the primary external sharing path

Code and documentation:

- `scripts/refresh_public_handoff_bundle.sh`
- `scripts/publish_public_review_package.sh`
- `runtime/public_handoff/latest_refresh.json`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-second Implemented Item: APK Install Guide Page

The public APK download area now includes a device-test guide for phone and
tablet validation.

Implemented behavior:

- `scripts/publish_android_apk_download.sh` now writes
  `web_client/public/downloads/install.html` with installation prerequisites,
  APK hash details, phone layout checks, tablet layout checks, and the
  recording/upload/status functional flow
- `web_client/public/downloads/index.html` links to the install guide whenever
  the APK download assets are republished
- `scripts/publish_public_review_package.sh` includes `apk_install_guide` and
  `install_guide_url` in the public review package
- `scripts/smoke_public_access.sh` verifies `/downloads/install.html` and
  checks guide markers before external sharing passes
- refresh summary JSON now carries the install guide URL alongside the APK
  download URL

Code and documentation:

- `scripts/publish_android_apk_download.sh`
- `scripts/publish_public_review_package.sh`
- `scripts/refresh_public_handoff_bundle.sh`
- `scripts/smoke_public_access.sh`
- `web_client/public/downloads/index.html`
- `web_client/public/downloads/install.html`
- `web_client/public/handoff/public-review-package.json`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-third Implemented Item: Public APK Device Install Check

The published public APK can now be installed and launched on a connected
Android device through a dedicated verification script.

Implemented behavior:

- `scripts/install_android_public_debug_apk.sh` installs
  `web_client/public/downloads/AiPmsAndroidClient-responsive-public-debug.apk`
  with `adb install -r`
- the script grants microphone permission and launches `com.aipms/.MainActivity`
  after installation
- by default it targets one USB-connected physical phone or tablet; emulator
  testing is allowed only with `AIPMS_ALLOW_EMULATOR=1`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1` verifies APK presence, SHA256, and writes a
  summary without requiring a connected device
- install/dry-run results are written to
  `runtime/android_public_install/latest_install_check.json`

Code and documentation:

- `scripts/install_android_public_debug_apk.sh`
- `runtime/android_public_install/latest_install_check.json`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-fourth Implemented Item: Public Review Response Template

The public handoff bundle now includes a copyable response template so each
owner can report review status in the same format.

Implemented behavior:

- `scripts/publish_public_review_package.sh` writes
  `web_client/public/handoff/review-response-template.md`
- the template captures reviewer, owner scope, result status, checked items,
  requested changes, questions, unverified items, and final comments
- the public handoff page links to the response template next to the review
  package JSON
- `public-review-package.json` now exposes `review_response_template` and a
  `response_template` contract with accepted result values
- `scripts/smoke_public_access.sh` verifies the template route and required
  response markers before public handoff passes

Code and documentation:

- `scripts/publish_public_review_package.sh`
- `scripts/refresh_public_handoff_bundle.sh`
- `scripts/smoke_public_access.sh`
- `web_client/public/handoff/index.html`
- `web_client/public/handoff/review-response-template.md`
- `web_client/public/handoff/public-review-package.json`
- `README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-fifth Implemented Item: Public Review Response Collector

Filled owner review responses can now be collected into local JSON and Markdown
summaries.

Implemented behavior:

- `scripts/collect_public_review_responses.sh` creates
  `runtime/review_responses/inbox/` and accepts filled Markdown copies of the
  public response template
- the collector parses reviewer, owner scope, result status, one-line summary,
  P1/P2/P3 change request counts, question count, and unverified item count
- summaries are written to `runtime/review_responses/latest_summary.json` and
  `runtime/review_responses/latest_summary.md`
- the collector handles an empty inbox without failing and leaves an inbox
  README with filename guidance
- `public-review-package.json` now documents the local response collection
  command and summary output paths

Code and documentation:

- `scripts/collect_public_review_responses.sh`
- `scripts/publish_public_review_package.sh`
- `scripts/refresh_public_handoff_bundle.sh`
- `runtime/review_responses/latest_summary.json`
- `runtime/review_responses/latest_summary.md`
- `README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-sixth Implemented Item: Web/App Execution Hub

Web and Android execution paths are now visible from one public route and one
local launcher command.

Implemented behavior:

- `scripts/publish_public_execution_hub.sh` writes
  `web_client/public/run/index.html` and
  `web_client/public/run/execution.json`
- the execution hub links to Web console, APK download, APK install guide,
  Platform API, Collection API, Analysis Server, handoff page, and review
  package JSON
- the execution JSON records public URLs, local URLs, Android APK metadata,
  required run commands, and minimum manual checks
- `scripts/run_local_execution_stack.sh` starts PostgreSQL, Collection API,
  Analysis Server, Analysis Worker, Platform API, and React Web in reusable
  `screen` sessions and prints local URLs after health checks
- reusable local service screens are kept only when the matching local health
  URL returns HTTP 200; stale Collection, Analysis, Platform, and Web screens
  are restarted automatically
- React Web header now exposes `실행 허브` next to APK download and handoff
- public refresh and smoke verification include `/run/` and
  `/run/execution.json`

Code and documentation:

- `scripts/publish_public_execution_hub.sh`
- `scripts/run_local_execution_stack.sh`
- `scripts/refresh_public_handoff_bundle.sh`
- `scripts/smoke_public_access.sh`
- `web_client/src/main.tsx`
- `web_client/public/run/index.html`
- `web_client/public/run/execution.json`
- `web_client/public/handoff/index.html`
- `README.md`
- `web_client/README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-seventh Implemented Item: Public Runtime Manifest Binding

React public pages now prefer the generated execution manifest instead of
hardcoded tunnel URLs.

Implemented behavior:

- `web_client/src/main.tsx` adds `usePublicExecutionManifest`, which loads
  `/run/execution.json` when available
- `/run/` uses manifest-provided public URLs, execution commands, minimum
  checks, and Android APK metadata before falling back to constants
- `/downloads/` uses manifest APK metadata and download URLs before falling
  back to the static debug APK constants
- `/handoff/` uses manifest Web/API/APK URLs before falling back to the current
  hardcoded quick-tunnel values
- documentation now states that React public routes treat
  `/run/execution.json` as the primary runtime source

Code and documentation:

- `web_client/src/main.tsx`
- `README.md`
- `web_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-eighth Implemented Item: Tester-Friendly APK Alias

The Android public debug APK now has a short installer filename for external
testers while retaining the traceable build filename.

Implemented behavior:

- `scripts/build_android_public_debug.sh` copies the public debug build to
  `artifacts/apk/AI-PMS-Recorder.apk`
- `scripts/publish_android_apk_download.sh` publishes
  `web_client/public/downloads/AI-PMS-Recorder.apk` beside
  `AiPmsAndroidClient-responsive-public-debug.apk`
- `downloads/android-apk.json` includes `apk_alias`
- the download and install guide pages use `AI-PMS-Recorder.apk` as the primary
  download button and keep the long filename as the developer/build trace link
- public execution and review packages expose both the tester-facing alias URL
  and the traceable build filename URL
- public smoke verifies both APK URLs are downloadable and larger than 1 MB

Code and documentation:

- `scripts/build_android_public_debug.sh`
- `scripts/publish_android_apk_download.sh`
- `scripts/publish_public_execution_hub.sh`
- `scripts/publish_public_review_package.sh`
- `scripts/smoke_public_access.sh`
- `web_client/src/main.tsx`
- `README.md`
- `android_client/README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/18_part_handoff_drafts.md`

## Sixty-ninth Implemented Item: Screen-Design-Based Web UI And Direct APK Handoff

The Drive screen-design image set has been reconciled into the React Web
workspace and the install package has been copied to a direct tester-facing APK
folder.

Implemented behavior:

- reviewed the latest image files under `../1. 화면설계서/` as the UI reference
  set for the Web/App visualization pass
- rebuilt the React Web visual console as a MEETFLOW/PMS workspace with a navy
  sidebar, KPI summary strip, project task board, document space, meeting
  review/approval panel, and Android phone-preview panel
- kept the Web layout responsive for phone/tablet preview widths while retaining
  the desktop PMS workspace density
- preserved the install package as a real `.apk` file at
  `artifacts/apk/AI-PMS-Recorder.apk`
- copied the same tester-facing package to the top-level Drive handoff folder:
  `../배포_APK/AI-PMS-Recorder.apk`

Code and documentation:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `artifacts/apk/AI-PMS-Recorder.apk`
- `../배포_APK/AI-PMS-Recorder.apk`
- `README.md`
- `docs/15_mvp_first_implementation.md`
- `docs/16_drive_source_inventory.md`

## Seventieth Implemented Item: Direct APK Handoff Verification Files

The top-level Drive APK handoff folder now includes installer-facing validation
files without wrapping the APK in a zip archive.

Implemented behavior:

- `../배포_APK/README.md` explains direct APK installation, phone/tablet target,
  API URL checks, and the manual recording/upload/status verification flow
- `../배포_APK/AI-PMS-Recorder.sha256` records the APK checksum beside the file
- `../배포_APK/apk_manifest.json` records artifact type, responsive target,
  source artifact, handoff path, SHA256, size, and required manual checks
- the actual install file remains `../배포_APK/AI-PMS-Recorder.apk`

Code and documentation:

- `../배포_APK/README.md`
- `../배포_APK/AI-PMS-Recorder.sha256`
- `../배포_APK/apk_manifest.json`
- `docs/15_mvp_first_implementation.md`
- `docs/16_drive_source_inventory.md`

## Seventy-first Implemented Item: Screen-Design Fidelity Pass

Web and Android UI have been reorganized to follow the Drive screen-design
image set more closely.

Implemented behavior:

- React Web visual console now renders a browser-framed MEETFLOW PMS surface
  with explicit `WEB-01`, `WEB-02`, `WEB-03`, `WEB-04`, `ADMIN-01`, and
  `APP-01~05` design reference labels
- Web includes dedicated workspace, kanban board, document table, review and
  approval, operations/admin dashboard, and Android app-flow preview sections
- Android native UI now follows the APP-01 to APP-05 order: login/home,
  project selection, meeting settings, recording, and upload/analysis status
- the latest Android debug APK was rebuilt and copied back to
  `../배포_APK/AI-PMS-Recorder.apk` and `/Users/ppp/Downloads/AI-PMS-APK/`

Verification:

- `npm run build`
- `ANDROID_CLEAN_BUILD=0 bash scripts/build_android_debug.sh`
- Browser layout checks at 1280px and 390px width with no body horizontal
  overflow
- APK SHA256 and `apk_manifest.json` validation

## Seventy-second Implemented Item: Screen-Design UI Smoke Verification

The screen-design UI handoff now has a repeatable smoke check for Web,
Android, and APK distribution drift.

Implemented behavior:

- `scripts/smoke_screen_design_ui.sh` verifies that the Drive screen-design
  image set is present before checking local implementation markers
- the smoke checks React Web markers for `WEB-01`, `WEB-02`, `WEB-03`,
  `WEB-04`, `ADMIN-01`, `APP-01~05`, app-flow preview, and admin preview
- the smoke checks CSS markers for browser frame, screen-design canvas, app
  strip, mini-phone, and admin metric strip
- the smoke checks Android `MainActivity.kt` markers for APP-01 to APP-05
  native UI ordering
- the smoke validates the direct APK checksum and `apk_manifest.json`
  size/hash/device-target metadata
- `AIPMS_SCREEN_UI_BUILD=1 bash scripts/smoke_screen_design_ui.sh` also runs
  the Web and Android builds

Code and documentation:

- `scripts/smoke_screen_design_ui.sh`
- `docs/15_mvp_first_implementation.md`

## Seventy-third Implemented Item: Project-Centered Integrated ERD

The data model is now captured as a single Project_ID-centered ERD that keeps
meeting automation as a PMS child module rather than a standalone product.

Implemented behavior:

- added a Drive-level ERD document that defines Platform DB, Collection DB, and
  external ERP/HCM ledger boundaries
- added a Mermaid ERD source that combines Project Core, meeting collection and
  analysis, PMS conversion, resource/cost feedback, distribution, security, and
  planned extension tables
- marked current implementation tables separately from planned extension tables
  so migration priority can be discussed without blocking current MVP work
- added a local implementation note for developers under `docs/21_erd_structure.md`
- added `scripts/smoke_erd_structure.sh` to verify that current Platform and
  Collection schema tables are represented in the ERD

Code and documentation:

- `../개요/AI_PMS_ERD_구조.md`
- `../개요/diagrams/19_ai_pms_integrated_erd.mmd`
- `docs/21_erd_structure.md`
- `scripts/smoke_erd_structure.sh`
- `docs/16_drive_source_inventory.md`

## Seventy-fourth Implemented Item: Project-Member Auto Distribution Flow

The Android and Web flows now follow the corrected PMS rule: the user selects
only the project, records the meeting, and the approved meeting content is sent
to that project's members automatically.

Implemented behavior:

- removed Android manual attendee checkbox selection from the active upload
  flow
- removed the Android pre-upload attendee save call
- changed Android APP-02 to project selection plus project-member automatic
  distribution target confirmation
- changed Web distribution UI from editable recipient rows to a read-only
  project-member recipient list
- changed Platform distribution to ignore client-provided recipient lists and
  always use `project_members` with active users and registered emails
- updated screen/API mapping, MVP requirements, traceability, install guide
  text, and smoke markers to reflect project-member automatic distribution

Verification target:

- `bash scripts/smoke_email_distribution.sh` verifies that a client-supplied
  outsider recipient is ignored and only project-member recipients are sent
- `bash scripts/smoke_screen_design_ui.sh` verifies the updated APP-02 markers

Code and documentation:

- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `backend/app/routers/distributions.py`
- `scripts/smoke_email_distribution.sh`
- `scripts/smoke_screen_design_ui.sh`
- `../1. 화면설계서/화면설계서.md`
- `../1. 화면설계서/화면별_API_매핑.md`
- `../2. 요구사항정의서/요구사항정의서.md`
- `../2. 요구사항정의서/요구사항_추적표.md`

## Seventy-fifth Implemented Item: 50-Person Saessak Tech Solutions Demo Fixture

The local demo company model now matches the requested PMS demonstration
scenario: 50-person AI and cloud B2B solution company, 50억 annual revenue,
15 projects, and project-member based meeting distribution.

Implemented behavior:

- added a deterministic demo company fixture generator for `새싹테크솔루션 주식회사`
- modeled 4 divisions: 경영본부, 연구소, 개발1본부, 개발2본부
- modeled 10 teams with 경영본부 5명, 연구소 15명, 개발1본부 15명, 개발2본부 15명
- modeled the development organization as 연구소 15명 plus 개발1본부 15명 plus 개발2본부 15명, 45명 total
- modeled the position ladder as 사원, 선임, 책임, 수석, 이사
- modeled duties as 팀장=책임급, 실장=수석급, 본부장=이사급
- generated 15 projects and 136 project memberships from the Excel assignment
  sheet
- stored division, position, duty, and company metadata in human
  `resource_profiles.metadata`
- kept meeting distribution compatible with the corrected rule because each
  project has explicit `project_members`

Verification target:

- `bash scripts/smoke_demo_company_seed.sh` validates headcount, developer
  count, revenue, division count, project count, position ladder, duty mapping,
  and three members per project

Code and documentation:

- `scripts/seed_demo_company.py`
- `scripts/smoke_demo_company_seed.sh`
- `docs/22_demo_company_structure.md`

## Seventy-eighth Implemented Item: Web Project Staffing Visualization

The Web visual console now loads selected project detail and surfaces the
seeded project staffing structure directly in the workspace UI.

Implemented behavior:

- fetches `/projects/{project_id}/detail` when the selected project changes in
  the visual console
- renders a `프로젝트 인력·투입` panel with participating members, project role,
  allocation percent, planned M/M, and allocated staffing cost
- shows annual salary snapshots only for admin/finance-facing UI state, while
  keeping allocation and project cost visible for project execution review
- keeps the meeting app flow aligned to project selection and project-member
  automatic distribution instead of manual attendee selection
- updated the screen-design smoke test to assert the project staffing panel and
  responsive styling markers
- corrected the older local module map from `Attendee Selection` to project
  member automatic distribution target

Verification target:

- `npm run build`
- `bash scripts/smoke_screen_design_ui.sh`

Code and documentation:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `scripts/smoke_screen_design_ui.sh`
- `docs/08_drive_based_reconfiguration.md`
- `docs/15_mvp_first_implementation.md`
- `docs/09_kim_heeseop_work_structure.md`

## Seventy-ninth Implemented Item: Project Member Detail Contract Alignment

The project detail API now matches the Drive screen/API mapping for automatic
distribution target confirmation.

Implemented behavior:

- added `email` and `user_role` to `ProjectMemberOut`
- updated project member upsert response and project detail response to select
  `users.email` and `users.role`
- updated the Web project staffing panel to show member email or an explicit
  missing-email marker
- updated Android project member DTO and automatic distribution target display
  to show member email
- added a contract smoke test for `/projects/{project_id}/detail` member
  payloads, including email, user role, project role, allocation percent,
  planned M/M, salary snapshot, and allocated cost
- extended screen-design smoke markers to protect Web and Android email display
- rebuilt and republished the responsive APK handoff with SHA256
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`

Verification target:

- `bash scripts/smoke_project_member_detail_contract.sh`
- `npm run build`
- `bash scripts/smoke_screen_design_ui.sh`
- `ANDROID_CLEAN_BUILD=0 bash scripts/build_android_public_debug.sh`

Code and documentation:

- `backend/app/schemas.py`
- `backend/app/routers/projects.py`
- `web_client/src/main.tsx`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/smoke_project_member_detail_contract.sh`
- `scripts/smoke_screen_design_ui.sh`
- `../배포_APK/AI-PMS-Recorder.apk`
- `../배포_APK/AI-PMS-Recorder.sha256`
- `../배포_APK/apk_manifest.json`
- `docs/15_mvp_first_implementation.md`
- `docs/09_kim_heeseop_work_structure.md`

## Eightieth Implemented Item: W-002 Project Member Management API Completion

The Platform project member API now covers the Drive screen/API mapping for
React Web W-002 participation management.

Implemented behavior:

- added `GET /projects/{project_id}/members` as a standalone member list API
- added `DELETE /projects/{project_id}/members/{user_id}` for member removal
- reused the same member payload contract as project detail, including email,
  user role, project role, allocation percent, planned M/M, salary snapshot, and
  allocated cost
- returns `404 Project not found` for unknown projects and `404 Project member
  not found` for missing memberships
- extended the project member contract smoke to verify list, delete, repeated
  delete failure, list-after-delete, and detail-after-delete behavior

Verification target:

- `bash scripts/smoke_project_member_detail_contract.sh`
- `git diff --check`

Code and documentation:

- `backend/app/routers/projects.py`
- `scripts/smoke_project_member_detail_contract.sh`
- `docs/15_mvp_first_implementation.md`
- `docs/09_kim_heeseop_work_structure.md`
- `README.md`

## Eighty-first Implemented Item: W-001 Project Management Update Contract

The Platform project API now covers the Drive screen/API mapping for React Web
W-001 project management with a stable project description field and update
contract.

Implemented behavior:

- added nullable `projects.description` to schema and service migration
- included `description` in project create, list, single read, and detail
  responses
- added `PUT /projects/{project_id}` for updating project name, description,
  and PM user reference
- preserved `404 Project not found` for missing project updates
- exposed project descriptions in the Web visual workspace header
- aligned Android project DTOs with the expanded project payload
- added a dedicated project management smoke test for `POST/GET/PUT/detail`
  contract behavior, including description clearing
- rebuilt and republished the responsive APK handoff with SHA256
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`

Verification target:

- `bash scripts/smoke_project_management_contract.sh`
- `npm run build`
- `ANDROID_CLEAN_BUILD=0 bash scripts/build_android_public_debug.sh`
- `git diff --check`

Code and documentation:

- `backend/migrations/0015_project_description.sql`
- `backend/schema.sql`
- `backend/app/schemas.py`
- `backend/app/routers/projects.py`
- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `scripts/smoke_project_management_contract.sh`
- `docs/15_mvp_first_implementation.md`
- `docs/09_kim_heeseop_work_structure.md`

## Eighty-second Implemented Item: Korean AI Note Service UI Benchmark Pass

The Web visual workspace now reflects actual AI note/transcription service
patterns more explicitly instead of showing only generic PMS cards.

Implemented behavior:

- added a Clova Note/Daglo-style note workbench with left note navigation,
  note search, meeting note list, central content-segment/timestamp transcript,
  AI memo panel, and fixed audio player bar
- retained the PMS-specific project context by showing Project_ID, project
  description, approval distribution, and project-member automatic delivery
  cue inside the note workflow
- replaced the phone preview with an app flow closer to recording-note apps:
  `All Boards`, active meeting board, recording card, waveform controls,
  `AI Summary` and `Scripts` tabs, AI summary card, and script snippet
- kept the Android native APK surface as a recorder-first app; note-service
  benchmark patterns are used only where they support recording, upload, and
  status confirmation rather than replacing the main recording console
- extended screen-design smoke markers to protect the benchmark UI structure

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `npm run build`
- `git diff --check`

Code and documentation:

- `web_client/src/main.tsx`
- `web_client/src/styles.css`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/smoke_screen_design_ui.sh`
- `docs/15_mvp_first_implementation.md`
- `docs/09_kim_heeseop_work_structure.md`

## Eighty-third Implemented Item: Android Recorder-First Home Correction

The Android APK home screen now prioritizes meeting recording over note-board
review. The app entry flow is project selection, Meeting ID, recording
start/stop, upload/analyze, and status check in one recording console.

Implemented behavior:

- changed the Android home title from dashboard-style navigation to `녹음 홈`
- moved project selection, Meeting ID, requester, recording meter, record
  button, upload button, and status check into the first screen
- moved note/summary style content behind the recording flow and removed the
  Android native `All Boards` home emphasis
- kept the MVP rule that project selection, not attendee selection, determines
  distribution targets
- updated smoke markers so future Android changes preserve the recorder-first
  home

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `bash scripts/verify_mvp_static.sh`

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

The Android app surface has been tightened again around the recorder-first MVP
rule. Empty profile/settings rows and visible technical connection wording were
removed from the Compose UI, and the home quick actions now call real handlers.

Implemented behavior:

- removed profile menu rows with no action, including technical connection copy
- simplified the home hero to a direct meeting-recording label
- removed quick-action helper descriptions from the user-facing app surface
- wired `새 녹음` to the recording handler instead of an empty click
- wired `파일 업로드` to the meeting list surface instead of an empty click
- replaced deprecated Compose icons/divider/border calls in `AppComposeUI.kt`
- rebuilt and republished the public APK handoff after the Android source change

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

The Android external audio-file upload path no longer uses deprecated
`startActivityForResult`/`onActivityResult`. This keeps the manual file upload
fallback while the main APK remains recorder-first.

Implemented behavior:

- added an Activity Result API audio picker using `ActivityResultContracts.GetContent`
- moved external audio URI handling into `handleExternalAudioUri`
- removed the deprecated request-code based file picker path
- renamed legacy helper functions that collided with Kotlin property setters
- changed APK copy steps in Android build/publish scripts to copy through a
  temporary target and then move into place, reducing Google Drive overwrite
  stalls
- rebuilt and republished the public APK handoff after the Android source
  change

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

## Ninety-fourth Implemented Item: User-Facing Copy Guard

The local scaffold now has a dedicated smoke gate for the user-facing copy rule:
app and Web screens must not expose implementation guidance, server wording,
prompt wording, local command text, or internal connection fields.

Implemented behavior:

- added `scripts/smoke_user_facing_copy_guard.sh`
- Android guard fails if `platformUrlInput`, `collectionUrlInput`, or
  `requestedByInput` is attached to a visible view
- Android guard scans visible labels, buttons, status text, and input hints for
  implementation terms
- Web guard scans visible text in the public run, handoff, download, and install
  HTML pages
- `scripts/smoke_screen_design_ui.sh` and `scripts/verify_mvp_static.sh` now
  run the guard

Verification target:

- `bash scripts/smoke_user_facing_copy_guard.sh`
- `bash scripts/smoke_screen_design_ui.sh`

## Ninety-fifth Implemented Item: Local Environment Doctor

The local scaffold now has a non-mutating environment doctor for the current
Mac mini and Google Drive development setup.

Implemented behavior:

- added `scripts/doctor_local_environment.sh`
- added `scripts/smoke_local_environment_doctor.sh`
- records local readiness reports in `runtime/local_environment/latest_doctor.json`
  and `runtime/local_environment/latest_doctor.md`
- validates required project directories, Python virtual environments, command
  availability, direct APK hash integrity, generated cache drift, and Web build
  dependency readiness
- classifies missing `web_client/node_modules/.bin/vite` as a warning with a
  concrete `npm install` recovery step
- wires the smoke into `scripts/verify_mvp_static.sh`

Verification target:

- `bash scripts/doctor_local_environment.sh`
- `bash scripts/smoke_local_environment_doctor.sh`

## Ninety-sixth Implemented Item: Drive-Safe Web Dependency Repair

Google Drive sometimes leaves `web_client/node_modules` partially locked or
empty during dependency installation. The Web dependency repair flow now keeps
the install cache outside Drive and links the project folder to that cache.

Implemented behavior:

- added `scripts/repair_web_dependencies.sh`
- installs Web dependencies to
  `$AIPMS_WEB_NODE_MODULES_CACHE` or `~/.cache/ai-pms/web_client`
- moves a broken in-Drive `web_client/node_modules` to
  `.node_modules_broken_<timestamp>` before creating the symlink
- updates the local environment doctor recommendation to use the repair script
- adds the repair script to the static verification presence gate

Verification target:

- `bash scripts/repair_web_dependencies.sh`
- `cd web_client && npm run build`
- `bash scripts/smoke_local_environment_doctor.sh`

## Ninety-seventh Implemented Item: Collection API Public Binding Guard

The external-network path for Android recording upload now has a server-side
binding guard. Collection API stays local by default and can be exposed through
VPN or Cloudflare tunnel without opening raw `8200` on every interface.

Implemented behavior:

- `scripts/run_collection_api.sh` default bind changed to `127.0.0.1:8200`
- `scripts/windows_run_collection_api.ps1` default bind changed to
  `127.0.0.1:8200`
- public interface binding requires both `AIPMS_COLLECTION_BIND_HOST=0.0.0.0`
  and `AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1`
- added `scripts/smoke_collection_public_binding_guard.sh`
- static verification checks that Collection API is not currently listening on
  `*:8200`
- external sharing procedure now requires production-secret rotation before
  restarting services

Verification target:

- `bash scripts/smoke_collection_public_binding_guard.sh`
- `curl -i http://127.0.0.1:8200/upload-sessions`

## One Hundred First Implemented Item: Platform And Analysis Public Binding Guard

Platform API and the Mac mini Analysis server now use the same external-network
binding posture as Collection API. This prevents raw `8000` and `8100` ports
from being reachable on every network interface while still allowing
Cloudflare/VPN tunnels to forward from local `127.0.0.1` services.

Implemented behavior:

- `scripts/run_platform_backend.sh` default bind changed to `127.0.0.1:8000`
- `scripts/run_analysis_server.sh` default bind changed to `127.0.0.1:8100`
- Windows run scripts default to local bind as well
- public interface binding requires explicit allow flags:
  `AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1` or
  `AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND=1`
- added `scripts/smoke_core_api_public_binding_guard.sh`
- continuous acceptance now fails required checks if Platform or Analysis is
  currently listening on a public interface

Verification target:

- `bash scripts/smoke_core_api_public_binding_guard.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Fifth Implemented Item: Web Public Binding Guard

The React Web dev server now follows the same external-network posture as the
API services. Raw `3000` stays local by default, and external access is routed
through VPN or Cloudflare tunnel URLs.

Implemented behavior:

- `scripts/run_local_execution_stack.sh` defaults Web to `127.0.0.1:3000`
- `scripts/run_public_tunnels.sh` restarts Web on `127.0.0.1:3000` before
  creating the Cloudflare tunnel
- Windows Web run scripts use the same local default
- `web_client/package.json` no longer defaults `npm run dev` or preview to
  `0.0.0.0`
- Vite is launched through `node ./node_modules/vite/bin/vite.js` so Google
  Drive executable-bit drift on `node_modules/.bin/vite` does not block Web
  startup
- direct `0.0.0.0` or `::` binding is rejected unless
  `AIPMS_WEB_ALLOW_PUBLIC_BIND=1` is explicitly set with
  `AIPMS_WEB_BIND_HOST=0.0.0.0`
- added `scripts/smoke_web_public_binding_guard.sh`
- continuous acceptance now treats raw public binding on `3000` as a required
  failure

Verification target:

- `bash scripts/smoke_web_public_binding_guard.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Sixth Implemented Item: APK Publication Freshness Guard

The public APK handoff now has a fast freshness check so Android code changes
cannot leave the tester-facing APK stale.

Implemented behavior:

- added `scripts/smoke_apk_publication_freshness.sh`
- verifies the built artifact, Web download APK, Web alias APK, and direct
  Drive APK share the same size and SHA256
- verifies `android-apk.json`, direct Drive SHA file, direct Drive manifest,
  execution hub manifest, public handoff package, install dry-run report, and
  portfolio summary point at the same APK hash
- continuous acceptance treats stale APK publication metadata as a required
  failure

Verification target:

- `bash scripts/smoke_apk_publication_freshness.sh`
- `bash scripts/run_continuous_acceptance_check.sh`

## Ninety-eighth Implemented Item: Continuous Acceptance Check

The ongoing 검수 loop now has a single command that checks the externally used
service path without running a full build every time.

Implemented behavior:

- added `scripts/run_continuous_acceptance_check.sh`
- writes JSON and Markdown reports under `runtime/continuous_acceptance/`
- checks Collection raw port exposure on `8200`
- checks Platform/Analysis raw port exposure on `8000` and `8100`
- checks local and public unauthenticated upload creation remains blocked
- checks wrong internal secret is rejected and valid internal secret still works
- checks production secrets are non-default and aligned across Platform,
  Collection, and Analysis
- adds static verification coverage for the ongoing acceptance command

Verification target:

- `bash scripts/run_continuous_acceptance_check.sh`

## Ninety-sixth Implemented Item: Drive Screen-Design UI Alignment

The Web and Android client surfaces were adjusted against the Google Drive
screen-design image set.

Implemented behavior:

- Android now presents a MEETFLOW-styled recorder-first home: white mobile
  surface, navy headings, teal brand mark, bordered cards, and waveform-style
  recording state
- Android still keeps the corrected MVP flow: project selection plus meeting
  title/ID, with no manual attendee selection
- React Web now uses the MEETFLOW brand in the left shell and app preview
- React Web first viewport follows the screen-design workspace structure:
  KPI cards, recent meetings, decisions, urgent tasks, kanban board, project
  status, document space, app preview, review panel, and admin dashboard
- Web app preview labels were converted from English placeholders to Korean
  APP-04/APP-05 screen labels
- `scripts/smoke_screen_design_ui.sh` was updated to guard the current
  Drive-screen-design markers

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `cd web_client && npm run build`
- `AIPMS_PLATFORM_BASE_URL=http://10.0.2.2:8000 AIPMS_COLLECTION_BASE_URL=http://10.0.2.2:8200 ANDROID_CLEAN_BUILD=1 AIPMS_ANDROID_TEMP_BUILD=1 bash scripts/build_android_public_debug.sh`
- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/verify_mvp_static.sh`

## Ninety-fifth Implemented Item: Android Recorder-First Simplification

Implemented behavior:

- Android active UI is now one recorder-first screen
- side menu, tab-like screen navigation, visible benchmark copy, guide cards,
  process descriptions, and chip rows are removed
- first section is `회의 녹음`; project selection and account controls are below it
- record button remains available immediately, while upload/status still check
  login and project selection
- screen-design smoke now guards against reintroducing Android side-menu or
  explanation markers

Code and scripts:

- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `android_client/README.md`
- `scripts/smoke_screen_design_ui.sh`
- `scripts/publish_android_apk_download.sh`

## Ninety-fourth Implemented Item: Current APK Handoff Republish

The Android source changed after the previous APK handoff, so the installable
APK and all public/direct metadata were republished from the current recorder
client build.

Implemented behavior:

- rebuilt the responsive Android debug APK from the current Android source
- republished the same installable `.apk` to:
  - `artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk`
  - `artifacts/apk/AI-PMS-Recorder.apk`
  - `web_client/public/downloads/AI-PMS-Recorder.apk`
  - `../배포_APK/AI-PMS-Recorder.apk`
  - `~/Downloads/AI-PMS-APK/AI-PMS-Recorder.apk`
- updated `scripts/publish_android_apk_download.sh` so
  `../배포_APK/README.md` is regenerated with the current APK hash
- removed hardcoded APK hash expectations from scope and screen-design smokes;
  they now validate the actual file hash against README, SHA file, manifest,
  install report, Web metadata, review package, and execution hub
- changed the Web fallback APK hash from a stale concrete checksum to a runtime
  metadata placeholder
- refreshed the dry-run install report and public review/execution package

Current republished APK SHA256:

```text
1bb02f28785ddd5da45dc4a94fbcd725e7ed9d2ace2b5f2788a6f56c8d944dc5
```

Verification target:

- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`
- `bash scripts/smoke_mvp_scope_definition.sh`
- `bash scripts/smoke_screen_design_ui.sh`
- `bash scripts/smoke_public_handoff_doctor.sh`
- `bash scripts/verify_mvp_static.sh`
- Android debug APK SHA256:
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`

## Eighty-fourth Implemented Item: Android Recorder View Reattach Stability

The recorder-first Android home reuses project, meeting, recording, upload, and
status controls across home and detail screens. Android `View` instances can
only have one parent, so screen navigation needed an explicit safe reattach
path.

Implemented behavior:

- added a `ViewGroup.attachChild` helper that removes a reusable child from its
  previous parent before adding it to the next section
- applied the helper to `sectionCard`, `screenScroll`, and `actionRow`
- verified the fix through a local temporary Android build outside the Google
  Drive sync path because the Drive-backed Gradle build stalled at Kotlin
  compilation
- republished the public-tunnel APK with the recorder-first home and safe view
  reattach fix

Verification target:

- local temporary Android public build: passed
- `bash scripts/build_android_debug.sh`: passed through temporary local build
- `bash scripts/build_android_public_debug.sh`: passed through temporary local build
- APK publish synchronization to Web downloads, `../배포_APK/`, and
  `/Users/ppp/Downloads/AI-PMS-APK/`: passed
- `bash scripts/smoke_mvp_scope_definition.sh`: passed
- `bash scripts/smoke_screen_design_ui.sh`: passed
- Android debug APK SHA256:
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`

## Eighty-fifth Implemented Item: Drive-Safe Android APK Build And Publish Path

Android Gradle builds stalled when running directly inside the Google
Drive-backed project path. The Android build and publish scripts now default to
a local temporary build directory and copy only the APK outputs back into the
workspace and handoff folders.

Implemented behavior:

- `scripts/build_android_debug.sh` builds under `/tmp/ai_pms_android_debug.*`
  by default, then copies the debug APK back to `android_client/build`
- `scripts/build_android_public_debug.sh` builds under
  `/tmp/ai_pms_android_public.*` by default, injects the public Platform and
  Collection URLs, then republishes the public APK artifacts
- `scripts/publish_android_apk_download.sh` now synchronizes the installable
  `.apk` to Web downloads, `../배포_APK/AI-PMS-Recorder.apk`, and
  `/Users/ppp/Downloads/AI-PMS-APK/AI-PMS-Recorder.apk`
- direct handoff checksum and `apk_manifest.json` are regenerated from the same
  source APK, without wrapping the installer in a zip file

Verification target:

- `bash scripts/verify_mvp_static.sh`: passed
- `bash scripts/smoke_screen_design_ui.sh`: passed
- direct APK copy hash check across artifacts, Web public, Web dist,
  `../배포_APK/`, and `/Users/ppp/Downloads/AI-PMS-APK/`: passed
- `git diff --check -- .`: passed
- direct APK SHA256:
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`

## Eighty-sixth Implemented Item: Direct APK Install Report And Guide Alignment

The direct APK handoff folder now has a current install guide and a generated
install verification report tied to the latest public recorder APK.

Implemented behavior:

- updated `../배포_APK/README.md` to remove the stale manual attendee selection
  step and replace it with project-member automatic distribution confirmation
- updated the direct APK guide checksum to
  `91b086369697ebcf05fc62ef4c9d6c6e0468411859388067472aa0400f9b7a64`
- extended `scripts/install_android_public_debug_apk.sh` so dry-run and
  physical-device install checks write both JSON and Markdown reports
- generated `runtime/android_public_install/latest_install_check.md` and
  `../배포_APK/설치검증_리포트.md`
- extended smoke checks so the direct handoff guide and report cannot drift
  back to attendee-selection or stale-hash wording
- aligned `android_client/local.properties` with the Mac mini Android SDK path
  so temporary Gradle builds no longer warn about a missing Windows SDK path

Verification target:

- `AIPMS_ANDROID_INSTALL_DRY_RUN=1 bash scripts/install_android_public_debug_apk.sh`: passed
- `bash scripts/smoke_mvp_scope_definition.sh`: passed
- `bash scripts/smoke_screen_design_ui.sh`: passed
- `bash scripts/build_android_debug.sh`: passed

## Eighty-seventh Implemented Item: Release APK Signing Readiness Gate

The current handoff APK remains debug-signed for short-term tester review. The
release signing path now has a readiness gate and Drive-safe release build path
before long-term external distribution.

Implemented behavior:

- `scripts/prepare_android_release_signing.sh` now writes both the
  `release-signing.env.example` file and a Markdown readiness report
- the readiness report is copied to `../배포_APK/릴리즈서명_준비상태.md`
- `scripts/build_android_release_apk.sh` now defaults to a temporary local
  Gradle build path under `/tmp/ai_pms_android_release.*`
- `scripts/smoke_android_release_readiness.sh` verifies the signing template,
  readiness reports, temp-build mode, and fail-fast behavior when signing
  environment variables are missing
- `scripts/verify_mvp_static.sh` now runs the release readiness smoke

Verification target:

- `bash scripts/smoke_android_release_readiness.sh`: passed

## Eighty-third Implemented Item: MVP Requirements Scope Gate

The user-supplied requirements definition is now converted into a canonical MVP
scope gate instead of a full platform backlog dump.

Implemented behavior:

- added `docs/23_mvp_requirements_definition.md` as the current MVP
  requirements definition
- separated MVP implementation/verification scope from deferred expansion
  areas such as full document management, notification center, advanced task
  board, user groups, resource/cost dashboard expansion, and external
  recipient management
- corrected scope and architecture docs so the active recording flow selects
  only a project and never requires attendee selection
- removed speaker-normalization wording from planning docs and replaced it with
  content-centered transcript structuring
- tightened analysis prompts and JSON contract descriptions so speaker and
  assignee fields stay null unless explicitly labelled in source material
- changed Web and Android benchmark transcript samples from person names to
  content segment labels such as `구간 01`
- added `scripts/smoke_mvp_scope_definition.sh` and wired it into the static
  verification suite

Verification target:

- `bash scripts/smoke_mvp_scope_definition.sh`
- `bash scripts/smoke_screen_design_ui.sh`
- `bash scripts/verify_mvp_static.sh`

## Seventy-sixth Implemented Item: Demo Company UI Surface Alignment

The Web demo surfaces now show the seeded 50-person 새싹테크솔루션 company
context instead of the earlier generic MEETFLOW-only placeholders.

Implemented behavior:

- changed the authenticated Web header to `새싹테크솔루션`
- added explicit 50-person AI and cloud B2B company copy to the Web workspace
- changed browser-frame and sidebar branding to `새싹테크솔루션`
- changed the admin dashboard summary to show 50명, 개발인원 45명, 연매출
  50억, 4개 본부, and 15개 프로젝트
- kept the corrected project-only meeting flow and project-member automatic
  distribution markers in the app screen preview
- extended screen-design smoke markers to check the demo company context

Verification target:

- `bash scripts/smoke_screen_design_ui.sh` verifies the Web and Android source
  markers for the 새싹테크솔루션 demo company surface

Code and documentation:

- `web_client/src/main.tsx`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/smoke_screen_design_ui.sh`
- `docs/09_kim_heeseop_work_structure.md`

## Seventy-seventh Implemented Item: Salary and Project Allocation Fixture

The demo company fixture now includes unique fictional employee names, annual
salary snapshots, project allocation percentages, planned M/M, and per-project
staffing cost snapshots.

Implemented behavior:

- replaced duplicated division-prefixed developer names with 45 unique
  fictional developer names
- added position-based annual salary generation with duty and developer
  allowances
- added `allocation_percent`, `planned_mm`, `staffing_note`,
  `annual_salary_krw`, and `allocated_cost_krw` to `project_members`
- exposed project member allocation fields through Platform project detail APIs
- updated Android project-member display to show allocation percent and M/M
- updated demo seed validation to check unique names, salary values, three
  members per project, 240% total allocation per project, and 2.4 planned M/M

Verification target:

- `bash scripts/smoke_demo_company_seed.sh`
- `bash scripts/apply_platform_schema.sh`
- `backend/.venv/bin/python scripts/seed_demo_company.py --apply`

Code and documentation:

- `backend/migrations/0014_project_member_staffing.sql`
- `backend/schema.sql`
- `backend/app/schemas.py`
- `backend/app/routers/projects.py`
- `android_client/src/main/java/com/aipms/client/AiPmsContracts.kt`
- `android_client/src/main/java/com/aipms/MainActivity.kt`
- `scripts/seed_demo_company.py`
- `scripts/smoke_demo_company_seed.sh`
- `docs/22_demo_company_structure.md`

## Eighty-eighth Implemented Item: Portfolio Evidence Bundle

BL-010 is now represented by an executable evidence bundle instead of an
unstructured screenshot checklist. The bundle ties together the Web run hub,
Android APK, public handoff package, install verification report, and core
MVP traceability message.

Implemented behavior:

- added `scripts/export_portfolio_evidence_bundle.sh`
- added `scripts/smoke_portfolio_evidence_bundle.sh`
- generated `../3. 포트폴리오 정리/AI_PMS_MVP_실행검증_포트폴리오.md`
- generated `runtime/portfolio_evidence/latest_portfolio_evidence.json`
- verified APK SHA256 consistency across direct Drive APK, Web download
  metadata, public execution manifest, and public review package
- recorded the current boundaries: physical Android recording/upload,
  real SMTP, real ERP, release keystore, and fixed-domain Cloudflare tunnel
  still require external credentials or devices
- wired the portfolio evidence smoke into `scripts/verify_mvp_static.sh`

Verification target:

- `bash scripts/smoke_portfolio_evidence_bundle.sh`: passed
- `bash scripts/verify_mvp_static.sh`

## Eighty-ninth Implemented Item: Formal Requirements Definition v0.2

The pasted requirements definition draft has been normalized into a generated
Markdown/DOCX pair so the Drive submission document and local development
scope gate share the same source.

Implemented behavior:

- added `scripts/export_formal_requirements_definition.py`
- added `scripts/smoke_formal_requirements_definition.sh`
- regenerated `docs/23_mvp_requirements_definition.md`
- regenerated `../2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md`
- generated
  `../2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx`
- corrected the duplicated/wrong section titles from the draft:
  `2.3` is now user roles, `3.3` is now system administrator requirements,
  section `4` is functional requirements, and `8.3` is the traceability matrix
- kept the active MVP rules aligned with the product decision: recording-first
  app, project-only selection, project-member automatic distribution, no
  mandatory attendee selection, no speaker mapping, and no AI auto-confirmation
- rendered the DOCX to 15 PNG pages and checked the page contact sheet for
  blank pages, table clipping, and layout overlap
- wired the formal requirements smoke into `scripts/verify_mvp_static.sh`

Verification target:

- `bash scripts/smoke_formal_requirements_definition.sh`: passed
- `bash scripts/verify_mvp_static.sh`

## Ninetieth Implemented Item: Public Requirements Handoff

The formal MVP requirements definition is now mirrored into the public Web
execution and review package so external reviewers can open the DOCX/Markdown
scope gate from the same hub as the APK and execution evidence.

Implemented behavior:

- added `scripts/publish_requirements_documents.sh`
- added `scripts/smoke_requirements_publication.sh`
- published the formal DOCX to
  `web_client/public/requirements/AI-PMS-requirements-v0.2.docx`
- published the formal Markdown to
  `web_client/public/requirements/AI-PMS-requirements-v0.2.md`
- generated `web_client/public/requirements/requirements.json` with file
  hashes, sizes, version, and MVP scope controls
- wired requirements links into `web_client/public/run/execution.json`,
  `web_client/public/run/index.html`,
  `web_client/public/handoff/public-review-package.json`,
  `web_client/public/handoff/review-response-template.md`, and
  `web_client/public/handoff/index.html`
- kept the public scope controls explicit: recording-first Android app,
  project-only selection, project-member automatic distribution, no mandatory
  attendee selection, no speaker mapping, and no AI auto-confirmation
- extended `scripts/smoke_public_access.sh` and
  `scripts/refresh_public_handoff_bundle.sh` to include the requirements
  manifest and document URLs
- changed `scripts/refresh_public_handoff_bundle.sh` so stale Cloudflare quick
  tunnel smoke failures are recorded in the refresh summary instead of
  preventing local handoff metadata generation; set
  `AIPMS_REFRESH_REQUIRE_PUBLIC_SMOKE=1` when live public smoke must be strict
- updated `scripts/smoke_public_access.sh` to accept explicit Web, Platform,
  Collection, and Analysis URLs before falling back to environment variables or
  quick-tunnel logs, with bounded curl timeouts and tunnel recovery guidance
- wired the requirements publication smoke into `scripts/verify_mvp_static.sh`
- updated `scripts/verify_mvp_static.sh` to refresh the public review and
  execution packages after requirements publication when public tunnel URLs are
  available, avoiding stale requirements hashes in handoff JSON

Verification target:

- `bash scripts/smoke_requirements_publication.sh`: passed
- `bash scripts/publish_public_review_package.sh`: passed
- `bash scripts/publish_public_execution_hub.sh`: passed
- `bash scripts/refresh_public_handoff_bundle.sh`: writes summary; current
  public smoke can fail when prior Cloudflare quick URLs have expired
- `bash scripts/verify_mvp_static.sh`

## Ninety-first Implemented Item: Public Smoke URL Resolution Guard

The public access smoke now has an explicit URL contract instead of relying only
on stale `runtime/tunnels/*.log` entries.

Implemented behavior:

- `scripts/smoke_public_access.sh` now accepts positional URLs in this order:
  Web, Platform, Collection, Analysis
- the same script still supports `AIPMS_PUBLIC_WEB_URL`,
  `AIPMS_PUBLIC_PLATFORM_URL`, `AIPMS_PUBLIC_COLLECTION_URL`, and
  `AIPMS_PUBLIC_ANALYSIS_URL`
- when neither positional nor environment values are present, it falls back to
  the latest quick-tunnel log URL
- curl calls now use bounded connect and total timeouts through
  `AIPMS_PUBLIC_SMOKE_CONNECT_TIMEOUT` and `AIPMS_PUBLIC_SMOKE_MAX_TIME`
- failed curl downloads clear their temp output file first so stale `/tmp`
  HTML cannot be mistaken for the current failure body
- failed public smoke now prints the concrete recovery command:
  `RESTART_PUBLIC_TUNNELS=1 AIPMS_REFRESH_START_TUNNELS=1 bash scripts/refresh_public_handoff_bundle.sh`
- README and the MVP implementation note now document the explicit URL call
  shape

Verification target:

- `bash -n scripts/smoke_public_access.sh`
- `bash scripts/smoke_public_access.sh --help`: passed
- default stale-tunnel failure path prints recovery guidance
- `bash scripts/refresh_public_handoff_bundle.sh`
- `bash scripts/verify_mvp_static.sh`

## Ninety-second Implemented Item: Public Handoff Doctor

External sharing now has a non-mutating doctor command that reports whether the
handoff package is locally consistent before any quick-tunnel restart is
attempted.

Implemented behavior:

- added `scripts/doctor_public_handoff.sh`
- added `scripts/smoke_public_handoff_doctor.sh`
- `doctor_public_handoff.sh` writes
  `runtime/public_handoff/latest_doctor.json` and
  `runtime/public_handoff/latest_doctor.md`
- the doctor validates public handoff JSON, execution JSON, APK metadata,
  requirements metadata, APK file hashes, requirements file hashes, quick-tunnel
  log URLs, DNS resolution, command availability, local service health, and the
  latest public smoke status
- stale or stopped public endpoints are reported as warnings when required
  local handoff artifacts are still consistent
- strict mode is available through `AIPMS_PUBLIC_HANDOFF_DOCTOR_STRICT=1`
- README now instructs operators to run the doctor before sharing links
- `scripts/verify_mvp_static.sh` runs the doctor smoke as part of the static
  verification set

Verification target:

- `bash scripts/doctor_public_handoff.sh`: passed with warning status for the
  currently expired quick-tunnel URLs
- `bash scripts/smoke_public_handoff_doctor.sh`: passed
- `bash scripts/verify_mvp_static.sh`

## Ninety-third Implemented Item: Android Attendee-Save Contract Removal

The Android recorder app now enforces the corrected MVP rule at the client
contract level: a user selects only the project and Meeting ID before
recording/upload. Project members remain visible as automatic distribution
targets, but the APK no longer carries an attendee-save API method or DTO.

Implemented behavior:

- removed `replaceMeetingAttendees` from the Android API client interface and
  Ktor implementation
- removed Android-only `MeetingAttendeesReplaceRequest` and
  `MeetingAttendeeDto` contracts
- kept project member detail lookup for automatic distribution confirmation
- added smoke guards that fail if Android source reintroduces
  `attendee_user_ids`, `/attendees`, attendee-save DTOs, or manual checkbox
  selection
- updated Android README and MVP implementation notes to state that the
  packaged APK is project-only for recording context

Verification target:

- `bash scripts/smoke_screen_design_ui.sh`
- `bash scripts/verify_mvp_static.sh`

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

Mac mini public runtime is now guarded by a lightweight macOS LaunchAgent.

Implemented behavior:

- `scripts/public_runtime_watchdog.sh` verifies local Web, Platform,
  Collection, and Analysis health and starts missing services when possible.
- The same watchdog verifies public Web, run hub, APK download, Platform,
  Collection, and Analysis URLs and writes the latest public runtime summary.
- `scripts/install_launchd_public_runtime.sh` installs the watchdog as
  `com.aipms.public-runtime` with `StartInterval=300` and `RunAtLoad=true`.
- Launchd execution uses the local mirror root and writes operational state
  under `~/.aipms/public-runtime-state` to avoid Google Drive File Provider and
  macOS LaunchAgent write-permission failures.
- Current quick `trycloudflare.com` URLs are kept alive by health checks, but
  long-running fixed URLs still require Cloudflare named tunnel and DNS.

Verification target:

- `bash scripts/install_launchd_public_runtime.sh --load`
- `cat ~/.aipms/public-runtime-state/runtime/always_on/latest_public_runtime.json`
- `bash scripts/run_continuous_acceptance_check.sh`

## One Hundred Twentieth Implemented Item: Cross-Server Connectivity Doctor

The project now has a first-pass operating rule and check script for using a
second PC without splitting PMS state.

Implemented behavior:

- `docs/29_analysis_failover_topology.md` defines the safe cross-server mode:
  one primary Platform server plus optional secondary Collection/Analysis
  runtime.
- The guide explicitly blocks active-active Platform usage for MVP because it
  would split meeting, approval, distribution, task, and risk state.
- `scripts/doctor_cross_server_connectivity.sh` checks the current primary
  Platform, Collection, and Web URLs from the public runtime summary.
- The same doctor can check an optional secondary host with
  `AIPMS_SECONDARY_HOST` and can require it with `AIPMS_EXPECT_SECONDARY=1`.
- Reports are written to `runtime/cross_server/latest_report.json` and
  `runtime/cross_server/latest_report.md`.

Verification target:

- `bash -n scripts/doctor_cross_server_connectivity.sh`
- `bash scripts/doctor_cross_server_connectivity.sh`

## One Hundred Twenty-first Implemented Item: Cloudflare DNS Origin Doctor

The project now has a direct `A` record origin readiness check for connecting a
Cloudflare proxied domain to the Mac mini public IP.

Implemented behavior:

- `scripts/doctor_cloudflare_dns_origin.sh` captures the current public IP,
  Mac mini LAN IP, local Web/API health, local `80`/`443` listener state, and
  optional domain health.
- `docs/30_cloudflare_dns_origin_runbook.md` documents the DNS records, router
  port-forwarding, reverse proxy shape, acceptance criteria, and security notes.
- The doctor supports `AIPMS_EXPECT_ORIGIN_PROXY=1` to require local `80`/`443`
  and `AIPMS_EXPECT_DOMAIN_LIVE=1` to require configured domain routes.

Verification target:

- `bash -n scripts/doctor_cloudflare_dns_origin.sh`
- `bash scripts/doctor_cloudflare_dns_origin.sh`

## One Hundred Twenty-second Implemented Item: Domainless GitHub Pages Web Deploy

The fixed-domain deployment path has been removed. The Web client now targets
the GitHub Pages default project URL, while API endpoints are supplied through
deployment variables.

Implemented behavior:

- `.github/workflows/deploy-web-pages.yml` builds `web_client` on push and
  deploys the `dist` artifact to GitHub Pages.
- Custom Web `CNAME` assumptions were removed from the deployment path.
- `web_client/vite.config.ts` accepts `VITE_BASE_PATH` so the build can target
  the GitHub Pages project subpath.
- `docs/19_cloudflare_named_tunnel_plan.md` documents variable-based API tunnel
  hostnames instead of hard-coded domains.
- `docs/31_git_web_deploy_runbook.md` defines the split between GitHub Pages
  Web hosting and Mac mini API hosting.

Verification target:

- `bash scripts/smoke_github_pages_cors.sh http://127.0.0.1:8000`
- `cd web_client && VITE_API_BASE=<platform-api-public-url> VITE_BASE_PATH=/llm-meeting-assistant/ npm run build`

## One Hundred Twenty-fourth Implemented Item: Mac mini Self-hosted Runner Deploy

The repository now includes a GitHub Actions workflow for deploying the service
stack through a Mac mini self-hosted runner.

Implemented behavior:

- `.github/workflows/deploy-mac-mini.yml` runs on a self-hosted macOS runner
  for service-path pushes.
- `scripts/deploy_mac_mini_from_runner.sh` syncs checked-out code to the Mac
  mini runtime root while preserving `.env`, `.venv`, `storage`, `runtime`, and
  `logs`.
- The deploy script installs backend, collection, analysis, and Web
  dependencies, applies schemas, restarts named `screen` service sessions, and
  reloads the public runtime LaunchAgent.
- `docs/32_self_hosted_runner_deploy_runbook.md` documents runner
  registration, repository variables, and manual dry-run commands.

Verification target:

- `bash -n scripts/deploy_mac_mini_from_runner.sh`
- `bash scripts/deploy_mac_mini_from_runner.sh --check`

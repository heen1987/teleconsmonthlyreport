# Drive-Based Reconfiguration

Last updated: 2026-06-27

## Authoritative Local Drive Path

The local Google Drive sync root for the project source documents is:

```text
/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1
```

The parent folder exists too, but it only contains the actual project folder
above plus local metadata. Development planning should use the nested project
folder as the authoritative document root.

## Reconfigured Product Definition

The product is an AI-PMS. The meeting recording, analysis, approval, and
distribution flow is the first module inside the PMS.

The organizing key is `Project_ID`. Every meeting, transcript, decision,
action item, risk, required resource, task candidate, schedule item, knowledge
record, distribution, and audit log should be traceable back to a project.

## Reference Documents Used

- Root `README.md`: project purpose, work principles, next work order
- `2. 요구사항정의서/요구사항정의서.md`: Android upload, Platform API storage, React review,
  approval, distribution
- `2. 요구사항정의서/AI_PMS_확장요구사항.md`: Project Core, schedule, resources, tasks,
  risk, cost, knowledge, dashboard, ERP/HCM boundary
- `2. 요구사항정의서/Platform_API_상세요구사항.md`: auth, projects, meetings, minutes,
  approval, email, audit ownership
- `2. 요구사항정의서/Collection_API_상세요구사항.md`: upload sessions, audio assets, analysis
  jobs, worker lease, retries, callbacks
- `1. 화면설계서/화면설계서.md`: Android A-001 to A-004 and Web W-000 to W-009
- `5. 프로젝트관리/작업백로그.md`: API contract, JSON schema, Mac mini Worker, Platform/Collection
  split, AI-PMS expansion
- `4. 협업가이드/협업_운영가이드.md`: role split and Definition of Done
- `개요/diagrams/*.mmd`: architecture, traceability, state, resource, and
  integration diagrams

## Target Module Map

```text
AI-PMS
├─ Platform API
│  ├─ Auth/User/Admin
│  ├─ Project Core
│  ├─ Project Members/Aliases/Glossary
│  ├─ Meetings
│  ├─ Analysis Results
│  ├─ Minutes Versions
│  ├─ Decisions/Action Items/Issues/Risks
│  ├─ Approval
│  ├─ Distribution
│  └─ Audit Logs
├─ Collection API
│  ├─ Upload Sessions
│  ├─ Audio Assets
│  ├─ Analysis Jobs
│  ├─ Worker Registry
│  ├─ Claim/Lease/Retry
│  ├─ Platform Callbacks
│  └─ Retention Tasks
├─ Mac mini Analysis Worker
│  ├─ Whisper.cpp STT
│  ├─ Content-Segment Structuring
│  ├─ Ollama LLM Analysis
│  └─ JSON Schema Validation
├─ Android App
│  ├─ Recorder-First Home
│  ├─ Project Selection
│  ├─ Project Member Auto Distribution Target
│  ├─ Recording/Upload
│  └─ Status Tracking
└─ React Web
   ├─ Login
   ├─ Project Management
   ├─ Meeting List
   ├─ Minutes Review/Edit
   ├─ Approval
   ├─ Email Distribution
   └─ User Admin
```

## Development Procedure

### 1. Lock Contracts First

- Finalize analysis JSON schema.
- Finalize Platform API endpoints.
- Finalize Collection API endpoints.
- Define state transitions for meetings, upload sessions, audio assets,
  analysis jobs, minutes, accounts, and email distribution.
- Define idempotency keys for upload, analysis result submission, approval,
  and distribution.

### 2. Build PMS Core Before Deep AI Features

- Implement employee-number users and admin user creation.
- Disable public user collection endpoints; create users only through admin/PMS
  managed registration.
- Issue opaque bearer access tokens and verify them from server-side token
  hashes.
- Require active bearer tokens on user-facing Platform APIs after the initial
  password-change gate.
- Implement project core, project members, aliases, glossary, and role policy.
- Implement meeting creation under a project.
- Store project context snapshots before analysis.

### 3. Split Collection Responsibility

- Create `collection_api/`.
- Move upload session, audio metadata, file validation, analysis job, worker
  claim, lease, retry, worker heartbeat, and retention logic out of
  `backend/`.
- Keep Platform API responsible for business state only.

### 4. Harden Mac Mini Worker

- Keep Ollama and Whisper.cpp local to the Mac mini.
- Use `qwen3:4b` as the default model for local structured analysis.
- Return structured JSON only.
- Mark every LLM result as draft/candidate.
- Add deterministic schema validation and failure states.

### 5. Complete Review And Approval Flow

- React Web starts with employee-number login and verifies bearer tokens before
  opening project/review screens.
- Android starts with employee-number login and verifies bearer tokens before
  project lookup/upload.
- Platform rejects project, meeting, review, approval, dashboard, task, and
  resource requests without an active bearer token.
- React Web reviews transcript, summary, decisions, action items, risks, and
  required resources.
- User edits assignee, due date, priority, and project linkage before approval.
- Approved action items become PMS task candidates.
- Approved decisions become project decision records.
- Resource demand candidates can become assignment/reservation allocations with
  Resource Pool availability checks and duplicate-window conflict records.
- Distribution is allowed only after approval.

### 6. Expand Into AI-PMS

- Connect action item due dates to schedule and milestones.
- Connect required resources to resource demand.
- Add capacity calendar blocks after the first Resource Pool profile,
  availability, assignment/reservation, and conflict checks.
- Record usage/time sheet/cost candidates, route them through finance/PM
  review, queue approved payloads for external ERP handoff, send them through a
  controlled connector/outbox path, and reconcile external ERP responses without
  writing to the external ledger directly.
- Promote delayed tasks, cost overruns, unassigned resource demands, resource
  allocation conflicts, and resource usage overruns into risk candidates.
- Add operations queue visibility and manual recovery actions.
- Promote approved meeting output into project knowledge records, expose it in
  Web search/detail UX, then add evidence-linked drill-down and RAG/Q&A.

## Local Scaffold Mapping

Current local scaffold:

- `backend/`: Platform API PoC with migration-managed PostgreSQL schema. It
  currently includes transitional `analysis_jobs` and approval-time project
  knowledge indexing.
- `analysis_server/`: Mac mini Analysis Worker API.
- `collection_api/`: Collection API scaffold for upload sessions, audio assets,
  analysis jobs, worker heartbeat, claim, lease, retry, completion, and
  migration-managed PostgreSQL schema.

Next implementation milestone:

1. Run end-to-end recording/upload on a USB-connected physical Android device.
2. Configure real SMTP provider credentials and load the recurring retry
   scheduler.
3. Configure production ERP endpoint credentials and load the recurring handoff
   scheduler for handed-off cost payloads.
4. Replace temporary quick tunnel URLs with a Cloudflare named tunnel or other
   fixed domain, then rebuild the public Android APK against the fixed Platform
   and Collection URLs.
5. Prepare Android release signing and produce a signed release APK before
   long-term external distribution.

## Acceptance Rules

- No PMS state can be changed by raw LLM output alone.
- Every official state change needs deterministic validation and audit logs.
- Unauthorized project context must not be sent to the LLM.
- Approved minutes only can be distributed.
- External ERP/HCM/accounting systems remain the official ledgers.

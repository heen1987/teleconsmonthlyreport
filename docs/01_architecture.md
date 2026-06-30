# Architecture

## Target Structure

```text
Android App / React Web
        |
        v
AI-PMS Backend API
  - auth/user module
  - project module
  - meeting module
  - upload/collection module
  - analysis job module
  - minutes review/approval module
  - distribution module
  - PMS reflection module
  - audit log module
        |
        v
Async Job Queue / Job Table
        |
        v
Local LLM AI Analysis Worker
  - Whisper.cpp STT
  - content-centered transcript structuring
  - Ollama local LLM
  - analysis JSON generation
  - JSON Schema validation
```

The external integration remains API-based. The internal MVP implementation is
module-based inside one AI-PMS Backend. Physical service separation is a later
scaling option, not the starting architecture.

## Source Of Truth Boundaries

- AI-PMS Backend owns users, projects, project members, meetings, upload
  sessions, audio asset metadata, analysis jobs, analysis results, minutes,
  approvals, distributions, PMS task/decision/risk/resource/knowledge records,
  and audit logs.
- The upload/collection module owns upload sessions, audio metadata, file
  validation, analysis job creation, worker leases, upload errors, and retry
  state inside the Backend boundary.
- The platform data module owns users, projects, meetings, minutes, approval,
  distribution, PMS reflection, and audit records inside the same Backend.
- Local LLM AI Analysis Worker owns no business state. It receives permitted
  job context, performs STT/LLM analysis, validates structured output, and
  returns results through the controlled job completion path.
- Android and React Web do not access databases directly.
- ERP/HCM/accounting systems remain external systems of record. AI-PMS stores
  project execution state and integration mappings, not official ledgers.

## Module Ownership Rules

| Module | Owns | Must Not Own |
|---|---|---|
| Auth/user | `users`, `tokens`, `password_reset_tokens` | audio files, analysis jobs |
| Project | `projects`, `project_members`, `project_glossaries` | file storage, STT execution |
| Meeting | `meetings`, `meeting_recording_refs`, meeting status | raw audio binary handling |
| Upload/collection | `ingestion_sessions`, `audio_assets` | minutes approval, email distribution |
| Analysis job | `analysis_jobs`, `analysis_job_attempts`, worker status | business interpretation of results |
| Local LLM AI Analysis Worker | transcript, summary, analysis JSON candidates | users, permissions, approvals |
| Minutes | `minutes_versions`, `minutes_decisions`, `minutes_action_items` | audio file validation |
| PMS reflection | `tasks`, `risks`, `project_decisions`, `resource_demands` | automatic confirmation of AI output |
| Distribution | `distributions`, `delivery_attempts` | sending unapproved minutes |
| Audit log | `audit_logs` | business workflow decisions |

Meeting creation and upload-session creation are separate responsibilities.
The meeting module creates `Meeting_ID`; the upload/collection module creates
`ingestion_session_id` and links it to the meeting. The Worker produces result
candidates only. Final persistence, versioning, approval, distribution, and PMS
reflection stay inside Backend modules.

## Current PoC Note

The current local scaffold still contains `backend/`, `collection_api/`, and
`analysis_server/` folders from the first PoC. The product architecture is now
defined as one AI-PMS Backend with internal modules plus a Local LLM AI
Analysis Worker. A later refactor should collapse `collection_api/` behavior
into Backend upload/collection and analysis-job modules unless a real
operational reason for service separation appears.

## AI Orchestration Pattern

All LLM calls pass through the Mac mini Analysis Worker or a single AI
orchestration layer.

1. AI-PMS Backend builds a permission-filtered project context snapshot.
2. Android uploads audio through the Backend API.
3. The Backend upload/collection module validates the audio and creates an
   analysis job.
4. Local LLM AI Analysis Worker claims the job with a lease.
5. Worker performs STT and local LLM analysis.
6. Worker returns structured JSON through job completion.
7. Backend validates schema and deterministic rules.
8. Backend stores draft analysis/minutes.
9. React Web user reviews, edits, approves, or rejects.
10. Approved items become PMS task/decision/risk/resource candidates.
11. Distribution and audit logs are stored.

## Why This Boundary Matters

The LLM is an interpretation layer. It must not become the database, the PMS
ledger, or the accounting authority. Official state changes are controlled by
rules, workflow, and audit logs.

## Event Backbone

The architecture should be event-ready even before a broker is introduced.
Important events:

- PROJECT_CREATED
- RESOURCE_DEMAND_CREATED
- RESOURCE_ASSIGNMENT_CONFIRMED
- SCHEDULE_CREATED
- RESOURCE_RESERVED
- MEETING_CREATED
- AUDIO_UPLOADED
- ANALYSIS_JOB_QUEUED
- ANALYSIS_JOB_CLAIMED
- MINUTES_GENERATED
- ACTION_ITEM_CREATED
- TASK_CREATED_FROM_ACTION_ITEM
- TASK_DELAYED
- RISK_CREATED
- COST_EXCEEDED
- MINUTES_APPROVED
- MINUTES_DISTRIBUTED

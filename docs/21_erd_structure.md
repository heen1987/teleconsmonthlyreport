# AI-PMS ERD Structure

Last updated: 2026-06-29

## Source Of Truth

The Drive-level ERD document is the authoritative structure:

```text
../개요/AI_PMS_ERD_구조.md
../개요/diagrams/19_ai_pms_integrated_erd.mmd
```

## Implementation Boundary

The current scaffold already implements the first-MVP database base:

- Platform DB: `backend/schema.sql`
- Collection DB: `collection_api/schema.sql`
- Existing project-core diagram: `../개요/diagrams/08_project_core_data_model.mmd`
- Existing resource loop diagram: `../개요/diagrams/18_resource_data_model.mmd`

The integrated ERD keeps `projects` as the root entity. Meeting recording,
audio collection, STT/LLM analysis, review, distribution, task conversion,
resource demand, cost feedback, and ERP handoff are child flows of the PMS
project core.

## Current Table Groups

| Group | Current tables |
|---|---|
| Auth/Admin | `users`, `access_tokens`, `password_reset_tokens`, `audit_logs` |
| Project Core | `projects`, `project_members`, `schedules` |
| Meeting/AI | `meetings`, `meeting_attendees`, `analysis_jobs`, `meeting_analyses` |
| PMS Conversion | `tasks`, `project_decisions`, `resource_demands`, `risks`, `project_knowledge_items` |
| Resource/Cost | `resource_profiles`, `resource_calendar_blocks`, `resource_allocations`, `resource_usage_entries`, `project_cost_candidates`, `project_cost_handoffs` |
| Distribution | `email_distributions`, `email_delivery_attempts` |
| Collection | `collection_upload_sessions`, `collection_audio_assets`, `collection_analysis_jobs`, `collection_workers`, `collection_job_event_logs` |

## Planned Extension Tables

- `contracts`
- `project_budgets`
- `wbs_items`
- `documents`
- `notifications`
- `external_system_mappings`
- `access_policies`

## Migration Notes

- Keep `project_id` on all operational entities for project-scoped querying.
- Normalize `tasks.assignee` to a nullable `assignee_user_id` FK in a future
  migration while preserving imported AI text as display metadata.
- Add WBS fields after the current Web/App flows stabilize:
  `tasks.wbs_id`, `schedules.wbs_id`, `resource_demands.wbs_id`.
- Do not store ERP/HCM official ledger data as AI-PMS-owned records. Store only
  references, candidates, and handoff state.

## Verification

```bash
bash scripts/smoke_erd_structure.sh
```

The smoke check verifies that all current Platform and Collection schema tables
are represented in the integrated ERD and that the planned extension tables are
visible in the Mermaid source.

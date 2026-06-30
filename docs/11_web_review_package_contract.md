# Web Review Package Contract

Last updated: 2026-06-27

## Purpose

This implements the next Kim Heeseop work item for W-004 to W-006. React Web
needs a stable response shape for minutes review, approval, and distribution
preparation.

Endpoint:

```http
GET /meetings/{meeting_id}/review-package
PUT /meetings/analyses/{analysis_id}/review-edits
```

Example contract:

- `contracts/web_review_package.example.json`

## Screen Mapping

| Screen | Purpose | Data Used |
|---|---|---|
| W-004 | minutes review/edit | meeting, result, counts, warnings |
| W-005 | approval | analysis_id, analysis_status, capabilities |
| W-006 | distribution | capabilities.can_distribute |

## Response Sections

- `meeting`: project-linked meeting metadata and current meeting status
- `analysis_id`: latest analysis result id
- `analysis_status`: draft/review/approval state
- `model_name`: local model used by Mac mini Worker
- `result`: `analysis.v1` payload
- `counts`: UI badge and tab counter values
- `capabilities`: controls which buttons React Web should enable
- `warnings`: non-blocking data quality or state mismatch warnings

## UI Rules

- Edit button is enabled when `capabilities.can_edit` is true.
- Save edits sends the full edited `analysis.v1` payload to
  `PUT /meetings/analyses/{analysis_id}/review-edits`.
- Approve/reject buttons are enabled when `capabilities.can_approve` or
  `capabilities.can_reject` is true.
- Approval is disabled in React Web while unsaved edits exist.
- Action items with `task_conversion_status = rejected` must not create PMS
  tasks during approval.
- Distribution is disabled until `capabilities.can_distribute` is true.
- `warnings` should be visible to reviewer/admin users, but do not automatically
  block review unless Platform policy later marks a warning as blocking.

## Current PoC Rule

The endpoint returns the latest `meeting_analyses` row for a meeting. In the
target Platform API, minutes versioning should replace this with an explicit
minutes version selector.

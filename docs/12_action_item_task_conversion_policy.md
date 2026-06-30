# Action Item To Task Conversion Policy

Last updated: 2026-06-26

## Purpose

This implements BL-028. AI-extracted action items should not become final PMS
tasks directly. They become draft task candidates after human approval of the
minutes.

## Policy

- LLM output uses `task_conversion_policy = manual_review_required`.
- LLM output starts as `task_conversion_status = candidate`.
- Platform approval creates PMS tasks with `status = draft`.
- Created tasks keep source analysis and source action item index.
- Created tasks keep priority, confidence, evidence refs, and conversion policy.
- Final task assignment, schedule linkage, and completion are PMS workflow
  actions, not LLM actions.

## Stored Task Fields

- `source_meeting_id`
- `source_analysis_id`
- `source_action_item_index`
- `priority`
- `ai_confidence`
- `evidence_refs`
- `conversion_policy`
- `conversion_status`

## Review UX Rule

W-004 should show action items as candidates. W-005 approval can create draft
tasks. W-006 distribution should show created task references only after
approval.

## Current Implementation

React Web can change assignee, due date, priority, or reject individual action
items before approval. Platform stores the edited `analysis.v1` draft with
`PUT /meetings/analyses/{analysis_id}/review-edits`. Approval skips action
items where `task_conversion_status = rejected`.

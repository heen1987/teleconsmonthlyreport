# Required Resource To Resource Demand Policy

Last updated: 2026-06-27

## Purpose

This implements the next AI-PMS expansion step after BL-028. Required resources
extracted from meeting analysis should become Resource Demand candidates, not
confirmed assignments or reservations.

## Policy

- LLM output may suggest required resources.
- Human approval of minutes creates `resource_demands` rows with
  `demand_status = candidate`.
- Candidate demands keep source meeting, source analysis, source item index,
  evidence, confidence, and date hints.
- Resource Manager or PM later confirms, rejects, assigns, or reserves the
  resource through the resource management workflow.
- Candidate demands whose needed start date has arrived can be promoted into
  risk candidates with a `resource_unassigned` evidence marker.
- The first workflow implementation stores human-created
  `resource_allocations` rows for assignments and reservations.
- Resource Pool entries are stored as `resource_profiles` and can be checked
  for date-window availability before assignment or reservation.
- Duplicate active reservations or assignments for the same `resource_name` and
  overlapping date window are stored as `status = conflict` so they can become
  visible risk/workflow candidates instead of disappearing as rejected API
  calls.

## Stored Fields

- `demand_id`
- `project_id`
- `source_meeting_id`
- `source_analysis_id`
- `source_required_resource_index`
- `name`
- `resource_type`
- `quantity`
- `needed_from`
- `needed_to`
- `reason`
- `evidence`
- `evidence_refs`
- `ai_confidence`
- `demand_status`
- `conversion_policy`

## Allocation Fields

`resource_profiles` records the managed Resource Pool:

- `resource_id`
- `resource_name`
- `resource_type`
- `capacity`
- `unit`
- `location`
- `owner_user_id`
- `status`
- `created_by`

`resource_allocations` records the first human-controlled step after demand
creation:

- `allocation_id`
- `demand_id`
- `project_id`
- `resource_id`
- `resource_name`
- `resource_type`
- `allocation_type` (`assignment` or `reservation`)
- `assignee_user_id`
- `quantity`
- `starts_on`
- `ends_on`
- `status`
- `conflict_reason`
- `created_by`

`resource_calendar_blocks` records Resource Pool capacity calendar blackout
windows before assignment or reservation:

- `block_id`
- `resource_id`
- `project_id`
- `starts_on`
- `ends_on`
- `block_type`
- `reason`
- `created_by`

`resource_usage_entries` records actual usage against a human-created
assignment or reservation:

- `usage_id`
- `allocation_id`
- `project_id`
- `resource_id`
- `resource_name`
- `resource_type`
- `usage_date`
- `quantity`
- `unit`
- `cost_amount`
- `usage_status`
- `note`
- `created_by`

`project_cost_candidates` records the cost feedback generated from actual
usage. These records are candidates inside AI-PMS, not finance/accounting
ledger postings:

- `cost_id`
- `project_id`
- `source_type`
- `source_id`
- `cost_type`
- `amount`
- `currency`
- `status`
- `description`
- `created_by`
- `reviewed_by`
- `reviewed_at`
- `review_note`

`project_cost_handoffs` records the approved-cost payload queued for an
external ERP/finance system. This is still not the official finance ledger:

- `handoff_id`
- `cost_id`
- `project_id`
- `target_system`
- `payload`
- `status`
- `external_reference`
- `requested_by`
- `created_at`
- `completed_at`
- `response_payload`
- `response_note`
- `response_received_by`
- `delivery_mode`
- `attempt_count`
- `last_error`
- `next_retry_at`
- `last_attempted_at`

## Status Rule

Cost candidate review status:

```text
candidate
  -> approved
  -> rejected
```

Only `admin`, `pm`, and `finance` roles can approve or reject cost candidates.
Approved cost candidates remain AI-PMS execution records until an external
finance/ERP integration accepts them into the official ledger.

ERP handoff status:

```text
approved cost candidate
  -> queued handoff
  -> sending
  -> sent
  -> retry_wait
  -> accepted | rejected | failed reconciliation
```

Only `admin` and `finance` roles can create or send ERP handoff records.
Handoffs are idempotent per `cost_id` and `target_system`.

Only `admin` and `finance` roles can reconcile ERP handoff results. A completed
handoff cannot be changed again. The reconciliation result is an integration
status in AI-PMS; it still does not make AI-PMS the official finance ledger.
`sent` means the payload was delivered to an external integration endpoint and
is awaiting ERP-side acceptance/rejection/failure reconciliation.

Current demand workflow status after allocation:

```text
candidate
  -> profile availability checked
  -> assigned
  -> reserved
  -> fulfilled
  -> risk candidate if unassigned when needed_from is due
```

Allocation status values:

```text
proposed
  -> confirmed
  -> released
```

Conflict path:

```text
proposed/confirmed allocation
  -> overlapping allocation request
  -> conflict allocation record
  -> demand_status = conflict
```

Future resource workflow extensions:

```text
resource profile
  -> capacity calendar block
  -> assignment/reservation
  -> time sheet/usage
  -> cost/risk feedback
```

Exception states:

- `rejected`
- `conflict`
- `cancelled`

## Boundary

AI-PMS may propose resource demand, but it must not directly allocate people,
rooms, vehicles, equipment, budget, or external ERP/HCM resources without human
review and policy checks.

Actual usage may create project cost candidates, but confirmed actual cost,
billing, payroll, and accounting entries remain outside AI-PMS until an
authorized ERP/finance integration accepts them.

Actual usage above the planned allocation quantity can be promoted into a risk
candidate with a `resource_usage_overrun` evidence marker. This remains a PMS
execution risk; it is not an accounting adjustment.

Resource Pool availability must consider both active assignments/reservations
and `resource_calendar_blocks`. Calendar blocks are human-created operational
constraints such as maintenance, holiday, blackout, or reservation hold, and
they do not originate from raw LLM output.

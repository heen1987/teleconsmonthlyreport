# State Transition Contract

Last updated: 2026-06-26

## Purpose

This document implements BL-009 and BL-018 for Kim Heeseop's integration role.
It defines the shared status vocabulary used by Android, React Web, Platform
API, Collection API, and the Mac mini Analysis Worker.

The machine-readable version is `contracts/status_catalog.json`.

## Meeting Status

```text
created
  -> upload_requested
  -> uploaded
  -> analysis_queued
  -> analyzing
  -> review_required
  -> approved
  -> distributed
```

Exception states:

- `upload_failed`
- `analysis_failed`
- `review_rejected`
- `distribution_failed`

Current PoC mapping:

- `POST /meetings` creates `created`
- `POST /meetings/analyze` moves `analysis_queued -> analyzing`
- successful analysis moves to `review_required`
- approval moves to `approved`

## Analysis Job Status

```text
queued
  -> claimed
  -> running
  -> completed
```

Exception/recovery states:

- `failed`
- `retry_wait`
- `cancelled`

Lease states:

- `active`
- `expired`
- `released`

Target Collection API rule:

- Collection API owns job creation, claim, heartbeat, lease timeout, retry, and
  cancellation.
- Mac mini Worker pulls jobs from Collection API and never directly changes PMS
  business state.
- Platform API receives only validated draft analysis results.

Current PoC rule:

- Platform API temporarily creates `analysis_jobs`.
- Platform API inserts `queued`, marks `running` before calling Analysis Server,
  and marks `completed` or `failed`.
- This temporary logic must move to `collection_api/` when that service is
  created.

## Minutes Status

```text
draft
  -> review_required
  -> approved
```

Exception states:

- `rejected`
- `superseded`

Approval rule:

- LLM output is always draft or candidate.
- Only a human-approved minutes version can create official PMS task, decision,
  risk, resource, knowledge, and distribution records.

## Distribution Status

```text
ready
  -> queued
  -> sending
  -> sent
```

Exception/recovery states:

- `partial_failed`
- `failed`
- `retry_wait`

Distribution rule:

- Distribution is blocked until minutes are approved.
- Every send attempt must create a delivery attempt record and audit log.

## Account Status

```text
password_change_required
  -> active
```

Exception states:

- `locked`
- `disabled`

Account rule:

- Development initial passwords are allowed only in local/demo mode.
- Production must force password change or remove the default password path.

## Next Code Step

Move the remaining temporary Platform `analysis_jobs` direct-call path into
Collection API, then connect Mac mini Worker to claim/start/complete/fail jobs
through Collection API.

# Collection API Scaffold

Last updated: 2026-06-27

## Purpose

This implements the next Kim Heeseop integration step: create the Collection
API boundary so upload session, audio asset, analysis job, worker heartbeat,
claim, lease, retry, and completion responsibilities can move out of Platform
API.

## Local Service

```text
collection_api/
  app/
    routers/collection.py
    domain/statuses.py
    schemas.py
    main.py
  migrations/
    0001_collection_initial.sql
  schema.sql
```

Run:

```bash
bash scripts/run_collection_api.sh
```

External-network binding policy:

- default bind is `127.0.0.1:8200`
- expose external Android access through VPN or Cloudflare tunnel
- direct `0.0.0.0:8200` binding requires
  `AIPMS_COLLECTION_BIND_HOST=0.0.0.0 AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1`
- run `bash scripts/generate_prod_secrets.sh` before external sharing and
  restart Platform, Collection, and Analysis services

Open:

- http://127.0.0.1:8200/health
- http://127.0.0.1:8200/docs

## Endpoints

- `POST /upload-sessions`
- `POST /upload-sessions/{session_id}/audio-file`
- `POST /audio-assets`
- `GET /audio-assets/{asset_id}`
- `POST /analysis-jobs`
- `GET /analysis-jobs`
- `GET /analysis-jobs/{job_id}`
- `GET /analysis-jobs/{job_id}/events`
- `POST /analysis-jobs/{job_id}/notify-platform`
- `POST /workers/heartbeat`
- `POST /analysis-jobs/claim`
- `POST /analysis-jobs/{job_id}/start`
- `POST /analysis-jobs/{job_id}/complete`
- `POST /analysis-jobs/{job_id}/fail`

## Current Boundary

Collection API now has its own tables:

- `collection_upload_sessions`
- `collection_audio_assets`
- `collection_analysis_jobs`
- `collection_workers`
- `collection_job_event_logs`

Platform meeting analysis requests create Collection transcript jobs first.
Android-style clients can also upload audio files to Collection, receive an
`asset_id`, and create asset-based analysis jobs. The Collection job stores
`transcript_text` for text jobs, `asset_id` for audio jobs, worker `model_name`,
and `result_json`. On successful completion, Collection calls the Platform
callback endpoint so PMS can store the draft review package.

## Worker Flow

```text
worker heartbeat
  -> claim queued job
  -> mark running
  -> use transcript_text or fetch audio asset
  -> run Whisper.cpp STT when audio is provided
  -> analyze transcript locally with Ollama
  -> complete or fail
  -> notify Platform on completion
```

Callback success and failure are recorded as `platform_callback_succeeded` or
`platform_callback_failed` in `collection_job_event_logs`. Completed jobs can be
manually replayed to Platform with `POST /analysis-jobs/{job_id}/notify-platform`.
Callbacks are signed with `X-Collection-Timestamp`,
`X-Collection-Key-Id`, and `X-Collection-Signature`. Platform verifies the
active key id and can temporarily accept previous key ids during a managed
secret rotation window.

Automatic Platform callback retry is enabled in the Collection API process. Due
callbacks can also be retried on demand with
`POST /analysis-jobs/callbacks/retry-due`. Callback state is visible on analysis
job detail responses through `platform_callback_status`,
`platform_callback_attempt_count`, `platform_callback_next_attempt_at`, and
`platform_callback_last_error`.

The worker loop command is:

```bash
bash scripts/run_analysis_worker_loop.sh
```

Failure rule:

- `fail` sets `retry_wait` while attempts remain.
- `fail` sets `failed` after max attempts.

Rotation smoke test:

```bash
bash scripts/smoke_callback_secret_rotation.sh
```

# Platform, Collection, And Analysis Integration

## Purpose

This document defines how the PMS Platform API, Collection API, and Mac mini
Analysis Worker connect.

The key rule:

> Collection owns upload/job/lease mechanics. The analysis worker produces draft
> AI results. Platform owns review, approval, PMS reflection, distribution, and
> audit.

## Runtime Topology

```text
Android app
  -> Collection Server
     -> stores audio file
     -> validates checksum
     -> creates analysis job
        -> Mac mini Analysis Server
           -> STT
           -> local LLM analysis
           -> JSON draft result
        -> Platform Server
           -> stores draft result
           -> review/approval
           -> creates tasks/decisions/documents
           -> distribution and audit log
```

For the current PoC, the Platform backend can call the analysis server directly
with a transcript through Collection API job orchestration:

```text
POST /meetings/analyze
  -> creates Collection upload session
  -> creates Collection transcript analysis job
  -> waits for Collection job completion
  -> stores meeting_analyses draft
```

The direct `POST /analyze/meeting` endpoint still exists on the analysis server
for local testing and service-level validation, but Platform no longer uses it
as the main meeting analysis path.

## Environment Variables

Platform backend:

```env
ANALYSIS_SERVER_URL=http://localhost:8100
ANALYSIS_REQUEST_TIMEOUT_SECONDS=120
COLLECTION_API_URL=http://localhost:8200
COLLECTION_POLL_TIMEOUT_SECONDS=180
COLLECTION_POLL_INTERVAL_SECONDS=2
COLLECTION_CALLBACK_SECRET_ID=dev-v1
COLLECTION_CALLBACK_SECRET=dev-collection-callback-secret
COLLECTION_CALLBACK_PREVIOUS_SECRETS=
COLLECTION_CALLBACK_MAX_AGE_SECONDS=300
```

Mac mini analysis server:

```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen3:4b
DEFAULT_CONTEXT_LIMIT=8192
WHISPER_CPP_BIN=/opt/homebrew/bin/whisper-cli
WHISPER_MODEL_PATH=models/whisper/ggml-small.bin
WHISPER_TIMEOUT_SECONDS=300
COLLECTION_API_URL=http://localhost:8200
WORKER_ID=mac-mini-worker-01
```

In a real LAN setup, `ANALYSIS_SERVER_URL` should point to the Mac mini IP:

```env
ANALYSIS_SERVER_URL=http://192.168.0.20:8100
```

## Current Transcript Job Contract

Platform -> Collection API:

```http
POST /upload-sessions
Content-Type: application/json
```

```json
{
  "project_id": "PJT-001",
  "meeting_id": "MTG-001",
  "file_name": "MTG-001.transcript.txt",
  "content_type": "text/plain"
}
```

```http
POST /analysis-jobs
Content-Type: application/json
```

```json
{
  "session_id": "UPL-001",
  "transcript_text": "회의 녹취 텍스트",
  "language": "ko",
  "priority": 100
}
```

Worker -> Collection API completion:

```json
{
  "worker_id": "mac-mini-worker-01",
  "payload": {
    "model_name": "qwen3:4b",
    "result": {
      "schema_version": "analysis.v1",
      "language": "ko",
      "summary": "string",
      "transcript_segments": [],
      "decisions": [],
      "action_items": [],
      "risks": [],
      "required_resources": [],
      "requires_human_approval": true
    }
  }
}
```

## Current Audio Job Contract

Android/client -> Collection API:

```http
POST /upload-sessions
Content-Type: application/json
```

```json
{
  "project_id": "PJT-001",
  "meeting_id": "MTG-001",
  "file_name": "meeting.wav",
  "content_type": "audio/wav",
  "expected_size_bytes": 123456,
  "checksum_sha256": "hex"
}
```

Collection returns an `upload_token`. The client uploads the binary file:

```http
POST /upload-sessions/{session_id}/audio-file
X-Upload-Token: {upload_token}
Content-Type: multipart/form-data
```

Then the client creates an asset-based analysis job:

```json
{
  "session_id": "UPL-001",
  "asset_id": "AUD-001",
  "language": "ko",
  "priority": 100
}
```

The Mac mini worker claims the job, reads the asset `storage_uri`, runs
Whisper.cpp STT, runs Ollama analysis, and completes the Collection job with
`model_name` and `result_json`. Collection then calls Platform:

```http
POST /integrations/collection/jobs/{job_id}/complete
Content-Type: application/json
X-Collection-Timestamp: 1710000000
X-Collection-Key-Id: dev-v1
X-Collection-Signature: sha256={hmac_sha256}
```

```json
{
  "job_id": "CJOB-001",
  "project_id": "PJT-001",
  "meeting_id": "MTG-001",
  "asset_id": "AUD-001",
  "audio_path": "file:///...",
  "model_name": "qwen3:4b",
  "result": {
    "schema_version": "analysis.v1",
    "language": "ko",
    "summary": "string",
    "transcript_segments": [],
    "decisions": [],
    "action_items": [],
    "risks": [],
    "required_resources": [],
    "requires_human_approval": true
  }
}
```

The signature is HMAC-SHA256 over:

```text
{timestamp}.{canonical_json_payload}
```

Platform rejects missing, expired, or invalid signatures with HTTP 401.
When `X-Collection-Key-Id` is present, Platform accepts only the configured
active key id or a configured previous key id. When the header is absent,
Platform tries active and previous secrets for legacy compatibility.

Callback secret rotation procedure:

1. Deploy Platform with `COLLECTION_CALLBACK_SECRET_ID` set to the new key id,
   `COLLECTION_CALLBACK_SECRET` set to the new secret, and
   `COLLECTION_CALLBACK_PREVIOUS_SECRETS` containing the old `key=secret`.
2. Deploy Collection with `PLATFORM_CALLBACK_SECRET_ID` and
   `PLATFORM_CALLBACK_SECRET` set to the new key id and secret.
3. Keep the previous secret configured until callback retry/replay windows have
   expired.
4. Remove the old entry from `COLLECTION_CALLBACK_PREVIOUS_SECRETS`.

## State Transition

Meeting status:

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

Failure:

```text
upload_failed
analysis_failed
review_rejected
distribution_failed
```

Analysis job status:

```text
queued
  -> claimed
  -> running
  -> completed
```

Failure/recovery:

```text
queued|claimed|running
  -> failed
  -> retry_wait
  -> queued
```

Meeting analysis status:

```text
draft
  -> review_required
  -> approved
```

Only approved results are reflected into PMS tasks, decisions, documents, and
distribution.

## Current PoC Endpoints

Platform backend:

```text
GET  /integrations/analysis-server/health
POST /integrations/collection/jobs/{job_id}/complete
POST /projects
POST /meetings
POST /meetings/analyze
POST /approvals/meeting-analyses/{analysis_id}/approve
```

Collection API:

```text
POST /upload-sessions
POST /upload-sessions/{session_id}/audio-file
GET  /audio-assets/{asset_id}
POST /analysis-jobs
GET  /analysis-jobs/{job_id}
GET  /analysis-jobs/{job_id}/events
POST /analysis-jobs/{job_id}/notify-platform
POST /analysis-jobs/claim
POST /analysis-jobs/{job_id}/start
POST /analysis-jobs/{job_id}/complete
POST /analysis-jobs/{job_id}/fail
```

Mac mini analysis server:

```text
GET  /health
POST /stt/transcribe
POST /analyze/meeting
```

## Failure Handling

If the Mac mini analysis server is unreachable:

- Collection API marks the analysis job `retry_wait` or `failed`
  depending on attempt count
- `meetings.status` becomes `analysis_failed`
- Platform API returns HTTP 503
- no draft meeting analysis is created
- no task/decision/document is created

If Platform callback fails:

- Collection keeps the analysis job `completed`
- Collection writes `platform_callback_failed` to `collection_job_event_logs`
- Collection stores callback status, attempt count, last error, and
  `next_attempt_at`
- Collection automatically retries due callbacks with exponential backoff
- operator can still replay with `POST /analysis-jobs/{job_id}/notify-platform`
- duplicate callbacks are idempotent by `source_collection_job_id`

## Connectivity Smoke Test

Start the Mac mini analysis server first:

```bash
bash scripts/run_analysis_server.sh
```

Start the Platform backend:

```bash
bash scripts/run_platform_backend.sh
```

Then verify both direct and Platform-mediated connectivity:

```bash
bash scripts/smoke_analysis_connection.sh
```

Expected output includes:

```json
{"status":"ok","app":"Mac mini Analysis Server","model":"qwen3:4b"}
```

and:

```json
{"reachable":true,"analysis_server_url":"http://localhost:8100","status":"ok"}
```

## Next Implementation Step

Harden the callback path for production:

1. Replace local `.env` callback secrets with an external secret manager value.
2. Notify Web users that minutes are ready for review.
3. Keep polling as a fallback for worker/callback failures.

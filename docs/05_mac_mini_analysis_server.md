# Mac mini Analysis Server Plan

## Decision

The Mac mini M4 16GB machine should be used as the analysis server.

It should not be positioned as the whole PMS server. The clean architecture is:

```text
Android app / Web
        |
        v
Collection Server
  - upload session
  - audio file storage
  - checksum validation
  - analysis job creation
        |
        v
Mac mini Analysis Server
  - audio download
  - STT
  - content-centered transcript structuring
  - local LLM analysis
  - JSON schema validation
  - result submission
        |
        v
Platform Server
  - project data
  - meeting minutes review
  - approval
  - task/decision/document reflection
  - distribution
  - audit log
```

## Why This Is The Right Boundary

The Mac mini has enough local compute for batch STT and 1B-4B local models, but
it should not become the source of truth for PMS data. PMS state, approvals,
tasks, decisions, and accounting data should stay in the Platform server.

The Mac mini analysis server returns draft analysis results only.

## Analysis Server Responsibilities

- Claim or receive analysis jobs
- Read audio file or transcript
- Run STT in batch mode
- Structure transcript segments without speaker identity inference
- Call local LLM through Ollama or llama.cpp
- Return structured JSON:
  - summary
  - decisions
  - action items
  - risks
  - evidence references
- Keep temporary files under a retention rule
- Report runtime/model health

## Analysis Server Must Not Do

- Approve meeting minutes
- Directly create final PMS tasks
- Directly modify Platform DB
- Post accounting journals
- Execute payments
- Change budget or contract values
- Bypass rule engine or approval workflow

## Recommended Runtime

Primary:

- Ollama
- Qwen default model
- Granite 4.1 3B for structured extraction/RAG
- Kanana 2.1B for Korean lightweight routing

STT:

- Whisper.cpp is installed locally with `models/whisper/ggml-small.bin`
- Faster-whisper or MLX Whisper can be evaluated later if speed becomes the
  bottleneck

Context:

- 8K default
- 16K only for long meetings
- one model active at a time

## API Boundary

Minimal PoC endpoints:

```text
GET  /health
POST /stt/transcribe
POST /analyze/meeting
```

Later production endpoints:

```text
POST /jobs/claim
POST /jobs/{job_id}/heartbeat
POST /jobs/{job_id}/complete
POST /jobs/{job_id}/fail
```

## Data Contract

The analysis result should remain a draft:

```json
{
  "summary": "string",
  "decisions": [],
  "action_items": [],
  "risks": [],
  "requires_human_approval": true
}
```

Platform server receives this result and performs review, approval, task
creation, document reflection, distribution, and audit logging.

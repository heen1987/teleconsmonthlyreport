# AI-PMS Collection API

This service owns the collection-side responsibilities for the meeting
intelligence module.

Responsibilities:

- upload sessions
- upload token metadata
- audio asset metadata
- analysis job queue
- worker heartbeat
- job claim/lease/retry
- completion/failure status
- integrated STT/LLM worker when `WORKER_LOOP_ENABLED=true`

Non-responsibilities:

- user authentication policy
- project/member business ownership
- minutes approval
- PMS task/decision/resource finalization

Current local scaffold uses FastAPI/PostgreSQL to match the existing PoC. The
current Mac mini deployment runs Collection and analysis together in this
service process; the legacy `analysis_server/` package is kept only for
compatibility and migration reference.

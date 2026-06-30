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

Non-responsibilities:

- user authentication policy
- project/member business ownership
- minutes approval
- PMS task/decision/resource finalization
- STT or LLM processing

Current local scaffold uses FastAPI/PostgreSQL to match the existing PoC.
The Drive target may later migrate this service to Flask/MySQL/Redis/RQ if the
team decides to follow that stack exactly.

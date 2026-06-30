# Mac mini Analysis Server

This service is intended to run on the Mac mini M4 16GB machine.

It is not the PMS platform server. It does not own project state, approvals,
tasks, decisions, accounting journals, or audit authority. It receives analysis
requests from the Collection/Platform server, runs local AI processing, and
returns structured draft results.

## Responsibilities

- STT batch processing with Whisper.cpp
- transcript cleanup without speaker identity inference
- local LLM meeting analysis
- summary, decisions, action items, risks extraction
- JSON schema validation
- model/runtime health checks

## Non-Responsibilities

- PMS DB ownership
- task creation finalization
- meeting minutes approval
- accounting journal posting
- payment, settlement, tax, or ledger updates
- bypassing rule engine or approval workflow

## Quick Start

```bash
cd ai_pms_bootstrap/analysis_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --port 8100
```

Open:

- Health: http://127.0.0.1:8100/health
- Docs: http://127.0.0.1:8100/docs

## Example

```bash
curl -X POST http://127.0.0.1:8100/analyze/meeting \
  -H "Content-Type: application/json" \
  -d '{
    "job_id": "JOB-001",
    "project_id": "PJT-001",
    "meeting_id": "MTG-001",
    "transcript": "민수님이 다음 주까지 테스트 장비 확보 가능 여부를 확인하기로 했습니다."
  }'
```

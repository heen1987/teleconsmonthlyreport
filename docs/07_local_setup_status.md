# Local Setup Status

Last verified: 2026-06-26

## Installed

- Homebrew packages: `postgresql@17`, `pgvector`, `python@3.12`, `libpq`, `whisper-cpp`
- Existing packages confirmed: `ollama`, `ffmpeg`, `cmake`
- Python virtual environments:
  - `backend/.venv`
  - `analysis_server/.venv`
- Whisper model:
  - `models/whisper/ggml-small.bin`
- PostgreSQL database:
  - database: `ai_pms`
  - user: `ai_pms`
  - extension: `vector`

## Ollama Models

- `qwen3:4b`
- `hf.co/ibm-granite/granite-4.1-3b-GGUF:Q4_K_M`
- `hf.co/tensorblock/kakaocorp_kanana-1.5-2.1b-instruct-2505-GGUF:Q3_K_M`
- `gemma3:4b`
- `hf.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF:Q4_K_M`
- Existing local models: `qwen2.5`, `qwen2.5-coder:7b`, `llama3.1:8b`

## Verified Flow

The local verification completed this path:

```text
platform backend /meetings/analyze
  -> analysis_jobs
  -> analysis_server /analyze/meeting
  -> Ollama qwen3:4b or structured fallback
  -> meeting_analyses draft
  -> approval endpoint
  -> tasks, project_decisions, audit_logs
```

Final DB counts after verification:

```text
projects: 3
meetings: 3
analysis_jobs: 3
meeting_analyses: 3
tasks: 2
project_decisions: 1
audit_logs: 3
```

## Drive-Based Scope Adjustment

The Drive source documents define the product as an AI-PMS. Meeting
intelligence is the first module, not the whole platform.

Current local services map to the target architecture like this:

- `backend/`: Platform API PoC
- `analysis_server/`: Mac mini Analysis Worker
- `collection_api/`: not created yet; next refactor target

The current `analysis_jobs` table is transitional. In the target architecture,
upload sessions, audio assets, analysis jobs, worker lease, retry, and retention
belong to Collection API.

## Run Commands

Start PostgreSQL:

```bash
bash scripts/run_postgres.sh
```

Start analysis server:

```bash
bash scripts/run_analysis_server.sh
```

Start platform backend:

```bash
bash scripts/run_platform_backend.sh
```

Smoke test:

```bash
bash scripts/smoke_analysis_connection.sh
```

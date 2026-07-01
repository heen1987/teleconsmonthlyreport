# ⚠️ collection_api — DEPRECATED

이 디렉토리(`collection_api/`)는 **`analysis_server/` 로 완전 통합**되었습니다.

## 마이그레이션 요약

| 역할 | 기존 위치 | 새 위치 |
|------|-----------|---------|
| 업로드 세션·오디오 에셋 | `collection_api/app/routers/collection.py` | `analysis_server/app/routers/collection.py` |
| 분석 job 큐·워커 관리 | `collection_api/app/routers/collection.py` | `analysis_server/app/routers/collection.py` |
| STT (Whisper.cpp) | `analysis_server/app/services/stt.py` | 동일 위치 (변경 없음) |
| LLM (Ollama) | `analysis_server/app/services/llm.py` | 동일 위치 (변경 없음) |
| 분석 워커 루프 | 외부 HTTP 루프 (`scripts/run_analysis_worker_loop.sh`) | `analysis_server/app/services/analysis_worker.py` (내부 asyncio) |
| DB 세션 | — | `analysis_server/app/db/session.py` |
| 인증 토큰 | `collection_api/app/services/auth_tokens.py` | `analysis_server/app/services/auth_tokens.py` |
| 상태 StrEnum | `collection_api/app/domain/statuses.py` | `analysis_server/app/domain/statuses.py` |
| DB 마이그레이션 | `collection_api/migrations/0001_collection_initial.sql` | `analysis_server/migrations/0001_collection_initial.sql` |

## 포트 변경

| 서비스 | 기존 포트 | 새 포트 |
|--------|-----------|---------|
| collection_api | 8200 | **Deprecated** |
| analysis_server (통합) | 8100 | **8200** |

## 실행 방법

```bash
# ✅ 이제 analysis_server 만 실행하면 됩니다
bash scripts/run_analysis_server.sh

# Windows
powershell -ExecutionPolicy Bypass -File scripts\windows_run_analysis_server.ps1
```

Android 클라이언트와 Platform API 콜백 URL 모두 `:8200` 을 그대로 사용합니다.

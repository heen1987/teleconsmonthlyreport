"""
⚠️ DEPRECATED: 외부 HTTP 워커 (구 버전)

이 모듈은 collection_api HTTP 엔드포인트를 호출하는 외부 워커였습니다.
현재는 app.services.analysis_worker (내부 asyncio 워커) 로 대체되었습니다.

이 파일은 코드 기록 보존용으로만 남겨둡니다. 실행하지 마세요.
"""
raise RuntimeError(
    "worker.py is deprecated. "
    "The integrated worker runs inside analysis_server/app/services/analysis_worker.py "
    "as an asyncio background task."
)

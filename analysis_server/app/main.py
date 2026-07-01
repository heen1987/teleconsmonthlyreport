import asyncio
import logging

from fastapi import FastAPI

from app.core.config import settings
from app.routers import analyze, stt
from app.routers import collection as collection_router
from app.schemas import AnalysisHealth

logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name)

app.include_router(analyze.router)
app.include_router(stt.router)
app.include_router(collection_router.router)

_INSECURE_DEFAULTS = {"", "dev-platform-callback-secret", "dev-collection-callback-secret", "change-me"}


def _warn_insecure_secrets() -> None:
    """외부 네트워크 노출 시 기본 시크릿 사용 경고."""
    issues: list[str] = []
    if settings.platform_callback_secret in _INSECURE_DEFAULTS:
        issues.append(
            "PLATFORM_CALLBACK_SECRET 이 기본값입니다."
            " Platform API 콜백 HMAC 서명이 우회될 수 있습니다."
        )
    if issues:
        sep = "=" * 60
        print(f"\n{sep}")
        print("⚠️  보안 경고: 외부 네트워크에 노출된 경우 즉시 조치하세요!")
        for msg in issues:
            print(f"   • {msg}")
        print("   → scripts/generate_prod_secrets.sh 를 실행하여 시크릿을 교체하세요.")
        print(f"{sep}\n")


async def _analysis_worker_loop() -> None:
    from app.services.analysis_worker import run_once

    logger.info("Internal analysis worker loop started (interval=%ds)", settings.worker_loop_interval_seconds)
    while True:
        try:
            await run_once()
        except Exception as exc:
            logger.error("Worker loop error: %s", exc, exc_info=True)
        await asyncio.sleep(settings.worker_loop_interval_seconds)


async def _callback_retry_loop() -> None:
    from app.services.collection import retry_due_callbacks

    retry_interval = max(settings.worker_loop_interval_seconds * 3, 60)
    logger.info("Platform callback retry loop started (interval=%ds)", retry_interval)
    while True:
        await asyncio.sleep(retry_interval)
        try:
            result = await asyncio.to_thread(retry_due_callbacks)
            if result["retried"] > 0:
                logger.info("Platform callback retry: %s", result)
        except Exception as exc:
            logger.error("Callback retry loop error: %s", exc, exc_info=True)


@app.on_event("startup")
async def startup() -> None:
    _warn_insecure_secrets()
    if settings.worker_loop_enabled:
        asyncio.create_task(_analysis_worker_loop())
        asyncio.create_task(_callback_retry_loop())
    else:
        logger.info("Internal worker loop disabled (WORKER_LOOP_ENABLED=false)")


@app.get("/health", response_model=AnalysisHealth)
def health():
    return AnalysisHealth(
        status="ok",
        app=settings.app_name,
        model=settings.ollama_model,
    )

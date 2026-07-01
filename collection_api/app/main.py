import asyncio
from contextlib import suppress

from fastapi import FastAPI

from app.core.config import settings
from app.routers import collection
from app.schemas import HealthOut

app = FastAPI(title=settings.app_name)
_callback_retry_task: asyncio.Task | None = None
_analysis_worker_task: asyncio.Task | None = None

app.include_router(collection.router)

# ── 알려진 기본값(공개 코드에 노출된 값) ─────────────────────────────────────
_INSECURE_DEFAULTS = {
    "",
    "dev-collection-callback-secret",
    "dev-v1",
    "change-me",
}


def _warn_insecure_secrets() -> None:
    """외부 네트워크 노출 시 기본 시크릿 사용 경고."""
    issues: list[str] = []
    if settings.platform_callback_secret in _INSECURE_DEFAULTS:
        issues.append(
            "PLATFORM_CALLBACK_SECRET 이 기본값('dev-collection-callback-secret')입니다."
        )
    if settings.platform_callback_secret_id in _INSECURE_DEFAULTS:
        issues.append("PLATFORM_CALLBACK_SECRET_ID 가 기본값('dev-v1')입니다.")
    if issues:
        sep = "=" * 60
        print(f"\n{sep}")
        print("⚠️  보안 경고: 외부 네트워크에 노출된 경우 즉시 조치하세요!")
        for msg in issues:
            print(f"   • {msg}")
        print(f"   → scripts/generate_prod_secrets.sh 를 실행하여 시크릿을 교체하세요.")
        print(f"{sep}\n")


async def _platform_callback_retry_loop():
    while True:
        try:
            await asyncio.to_thread(
                collection.retry_due_platform_callbacks_once,
                settings.platform_callback_retry_batch_size,
            )
        except Exception as exc:
            print(f"Platform callback retry loop failed: {exc}")
        await asyncio.sleep(settings.platform_callback_retry_interval_seconds)


async def _analysis_worker_loop():
    """내부 분석 워커 루프 — STT/LLM 처리를 인프로세스로 실행한다."""
    from app.services.analysis_worker import run_once  # 지연 import로 순환 방지

    while True:
        try:
            await run_once()
        except Exception as exc:
            print(f"Analysis worker error: {exc}")
        await asyncio.sleep(settings.worker_loop_interval_seconds)


@app.on_event("startup")
async def startup():
    _warn_insecure_secrets()
    global _callback_retry_task, _analysis_worker_task
    if settings.platform_callback_retry_loop_enabled:
        _callback_retry_task = asyncio.create_task(_platform_callback_retry_loop())
    if settings.worker_loop_enabled:
        _analysis_worker_task = asyncio.create_task(_analysis_worker_loop())


@app.on_event("shutdown")
async def shutdown():
    for task in (_callback_retry_task, _analysis_worker_task):
        if task:
            task.cancel()
            with suppress(asyncio.CancelledError):
                await task


@app.get("/health", response_model=HealthOut)
def health():
    return HealthOut(status="ok", app=settings.app_name, model=settings.ollama_model)

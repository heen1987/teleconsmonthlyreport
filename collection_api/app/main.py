import asyncio
from contextlib import suppress

from fastapi import FastAPI

from app.core.config import settings
from app.routers import collection
from app.schemas import HealthOut

app = FastAPI(title=settings.app_name)
_callback_retry_task: asyncio.Task | None = None

app.include_router(collection.router)


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


@app.on_event("startup")
async def startup():
    global _callback_retry_task
    if settings.platform_callback_retry_loop_enabled:
        _callback_retry_task = asyncio.create_task(_platform_callback_retry_loop())


@app.on_event("shutdown")
async def shutdown():
    if _callback_retry_task:
        _callback_retry_task.cancel()
        with suppress(asyncio.CancelledError):
            await _callback_retry_task


@app.get("/health", response_model=HealthOut)
def health():
    return HealthOut(status="ok", app=settings.app_name)

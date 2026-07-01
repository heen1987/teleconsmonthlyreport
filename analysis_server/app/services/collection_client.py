from __future__ import annotations

import httpx

from app.core.config import settings


def _timeout() -> httpx.Timeout:
    return httpx.Timeout(settings.collection_request_timeout_seconds)


def _internal_headers() -> dict[str, str]:
    secret = settings.collection_internal_api_secret
    return {"X-Internal-Secret": secret} if secret else {}


async def heartbeat() -> dict:
    async with httpx.AsyncClient(timeout=_timeout()) as client:
        response = await client.post(
            f"{settings.collection_api_url}/workers/heartbeat",
            headers=_internal_headers(),
            json={
                "worker_id": settings.worker_id,
                "worker_name": "Mac mini Analysis Worker",
                "model_name": settings.ollama_model,
                "status": "active",
                "host_info": {"runtime": "ollama"},
            },
        )
        response.raise_for_status()
        return response.json()


async def claim_job() -> dict | None:
    async with httpx.AsyncClient(timeout=_timeout()) as client:
        response = await client.post(
            f"{settings.collection_api_url}/analysis-jobs/claim",
            headers=_internal_headers(),
            json={"worker_id": settings.worker_id},
        )
        response.raise_for_status()
        return response.json()


async def get_audio_asset(asset_id: str) -> dict:
    async with httpx.AsyncClient(timeout=_timeout()) as client:
        response = await client.get(
            f"{settings.collection_api_url}/audio-assets/{asset_id}",
            headers=_internal_headers(),
        )
        response.raise_for_status()
        return response.json()


async def update_job(job_id: str, action: str, payload: dict | None = None, error_message: str | None = None) -> dict:
    async with httpx.AsyncClient(timeout=_timeout()) as client:
        response = await client.post(
            f"{settings.collection_api_url}/analysis-jobs/{job_id}/{action}",
            headers=_internal_headers(),
            json={
                "worker_id": settings.worker_id,
                "payload": payload or {},
                "error_message": error_message,
            },
        )
        response.raise_for_status()
        return response.json()

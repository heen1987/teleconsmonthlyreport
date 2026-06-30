from __future__ import annotations

import httpx

from app.core.config import settings


async def heartbeat() -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            f"{settings.collection_api_url}/workers/heartbeat",
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
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            f"{settings.collection_api_url}/analysis-jobs/claim",
            json={"worker_id": settings.worker_id},
        )
        response.raise_for_status()
        return response.json()


async def get_audio_asset(asset_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(f"{settings.collection_api_url}/audio-assets/{asset_id}")
        response.raise_for_status()
        return response.json()


async def update_job(job_id: str, action: str, payload: dict | None = None, error_message: str | None = None) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            f"{settings.collection_api_url}/analysis-jobs/{job_id}/{action}",
            json={
                "worker_id": settings.worker_id,
                "payload": payload or {},
                "error_message": error_message,
            },
        )
        response.raise_for_status()
        return response.json()

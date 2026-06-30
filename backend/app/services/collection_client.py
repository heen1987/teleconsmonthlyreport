from __future__ import annotations

import asyncio

import httpx

from app.core.config import settings
from app.schemas import MeetingAnalysisResult


class CollectionJobError(RuntimeError):
    pass


async def create_transcript_analysis_job(
    *,
    project_id: str,
    meeting_id: str,
    transcript: str,
    requested_by: str | None = None,
) -> str:
    base_url = settings.collection_api_url.rstrip("/")
    async with httpx.AsyncClient(timeout=10) as client:
        session_response = await client.post(
            f"{base_url}/upload-sessions",
            json={
                "project_id": project_id,
                "meeting_id": meeting_id,
                "requested_by": requested_by,
                "file_name": f"{meeting_id}.transcript.txt",
                "content_type": "text/plain",
                "expected_size_bytes": len(transcript.encode("utf-8")),
            },
        )
        session_response.raise_for_status()
        session = session_response.json()

        job_response = await client.post(
            f"{base_url}/analysis-jobs",
            json={
                "session_id": session["session_id"],
                "transcript_text": transcript,
                "language": "ko",
                "priority": 100,
            },
        )
        job_response.raise_for_status()
        return job_response.json()["job_id"]


async def wait_for_analysis_job(job_id: str) -> tuple[str, MeetingAnalysisResult]:
    base_url = settings.collection_api_url.rstrip("/")
    deadline = asyncio.get_running_loop().time() + settings.collection_poll_timeout_seconds

    async with httpx.AsyncClient(timeout=10) as client:
        while True:
            response = await client.get(f"{base_url}/analysis-jobs/{job_id}")
            response.raise_for_status()
            job = response.json()

            if job["status"] == "completed":
                if not job.get("result_json"):
                    raise CollectionJobError(f"Collection job {job_id} completed without result_json")
                return (
                    job.get("model_name") or "unknown",
                    MeetingAnalysisResult.model_validate(job["result_json"]),
                )
            if job["status"] in {"failed", "cancelled"}:
                raise CollectionJobError(f"Collection job {job_id} ended with status {job['status']}")
            if asyncio.get_running_loop().time() >= deadline:
                raise CollectionJobError(f"Timed out waiting for Collection job {job_id}")

            await asyncio.sleep(settings.collection_poll_interval_seconds)

from __future__ import annotations

import httpx

from app.core.config import settings
from app.schemas import AnalysisServerHealthOut, MeetingAnalysisResult


class AnalysisServerError(RuntimeError):
    pass


async def get_analysis_server_health() -> AnalysisServerHealthOut:
    url = settings.analysis_server_url.rstrip("/")

    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(f"{url}/health")
            response.raise_for_status()
    except httpx.HTTPError as exc:
        return AnalysisServerHealthOut(
            reachable=False,
            analysis_server_url=url,
            error=str(exc),
        )

    data = response.json()
    return AnalysisServerHealthOut(
        reachable=True,
        analysis_server_url=url,
        status=data.get("status"),
        app=data.get("app"),
        model=data.get("model"),
    )


async def request_meeting_analysis(
    *,
    job_id: str,
    project_id: str,
    meeting_id: str,
    transcript: str,
) -> tuple[str, MeetingAnalysisResult]:
    payload = {
        "job_id": job_id,
        "project_id": project_id,
        "meeting_id": meeting_id,
        "transcript": transcript,
        "language": "ko",
    }

    try:
        async with httpx.AsyncClient(
            timeout=settings.analysis_request_timeout_seconds
        ) as client:
            response = await client.post(
                f"{settings.analysis_server_url.rstrip('/')}/analyze/meeting",
                json=payload,
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise AnalysisServerError(str(exc)) from exc

    data = response.json()
    return (
        data.get("model_name", "unknown"),
        MeetingAnalysisResult.model_validate(data["result"]),
    )

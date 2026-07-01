"""
내부 분석 워커

analysis_server 프로세스 안에서 asyncio 백그라운드 태스크로 실행된다.
DB 와 서비스 모듈(app.services.collection)을 직접 호출하며,
외부 HTTP 요청을 일절 보내지 않는다.
"""
from __future__ import annotations

import asyncio
import logging

from app.core.config import settings
from app.domain.statuses import AnalysisJobStatus
from app.services import collection as svc
from app.services.llm import analyze_transcript
from app.services.stt import transcribe_audio_uri

logger = logging.getLogger(__name__)

_WORKER_NAME = "Integrated Analysis Worker"


async def run_once() -> None:
    """큐에서 job 하나를 꺼내 STT → LLM 분석 → 완료 처리."""

    # 1. heartbeat
    await asyncio.to_thread(
        svc.worker_heartbeat,
        settings.worker_id,
        _WORKER_NAME,
        settings.ollama_model,
        settings.aipms_analysis_port,
    )

    # 2. job 클레임
    job = await asyncio.to_thread(
        svc.claim_job,
        settings.worker_id,
        settings.default_lease_seconds,
    )
    if not job:
        return

    job_id = job["job_id"]
    claimed_status = job["status"]
    logger.info("Claimed analysis job %s", job_id)

    try:
        # 3. RUNNING 으로 전환
        await asyncio.to_thread(
            svc.start_job,
            job_id,
            settings.worker_id,
            claimed_status,
        )

        # 4. STT (transcript 없을 경우)
        transcript = job.get("transcript_text")
        if not transcript:
            asset_id = job.get("asset_id")
            if not asset_id:
                raise RuntimeError("Job has neither transcript_text nor asset_id")
            asset = await asyncio.to_thread(svc.get_audio_asset, asset_id)
            if not asset:
                raise RuntimeError(f"Audio asset {asset_id} not found")
            storage_uri = asset.get("storage_uri")
            if not storage_uri:
                raise RuntimeError(f"Audio asset {asset_id} has no storage_uri")
            transcript = await transcribe_audio_uri(storage_uri, job.get("language") or "ko")

        # 5. LLM 분석
        model_name, result = await analyze_transcript(transcript)

        # 6. 완료 처리
        completed_job = await asyncio.to_thread(
            svc.complete_job,
            job_id,
            settings.worker_id,
            model_name,
            result.model_dump(mode="json"),
        )
        logger.info("Completed analysis job %s (model=%s)", job_id, model_name)

        # 7. Platform API 콜백 (실패해도 워커 루프 계속)
        try:
            await asyncio.to_thread(svc.notify_platform_job_completed, completed_job)
        except Exception as cb_exc:
            logger.warning("Platform callback failed for %s (will retry): %s",
                           job_id, cb_exc)

    except Exception as exc:
        logger.error("Analysis job %s failed: %s", job_id, exc, exc_info=True)
        try:
            await asyncio.to_thread(
                svc.fail_job,
                job_id,
                settings.worker_id,
                AnalysisJobStatus.RUNNING.value,
                str(exc),
            )
        except Exception as status_exc:
            logger.error("Failed to mark job %s as failed: %s", job_id, status_exc)
        raise

"""
내부 분석 워커 (Integrated Analysis Worker)

Collection API 프로세스 내부에서 asyncio 백그라운드 태스크로 실행된다.
외부 HTTP 없이 직접 DB에 접근하여 job을 처리한다.

기존 analysis_server의 외부 워커 루프를 대체한다.
"""
from __future__ import annotations

import asyncio
import logging

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.core.config import settings
from app.db.session import get_connection
from app.domain.statuses import AnalysisJobStatus, PlatformCallbackStatus
from app.services.llm import analyze_transcript
from app.services.stt import transcribe_audio_uri

logger = logging.getLogger(__name__)

WORKER_NAME = "Integrated Analysis Worker"

_CALLBACK_JOB_COLUMNS = """
    job_id, session_id, asset_id, project_id, meeting_id, status,
    transcript_text, language, claimed_by, lease_expires_at, model_name,
    result_json, attempt_count, max_attempts,
    platform_callback_status, platform_callback_attempt_count,
    platform_callback_max_attempts, platform_callback_next_attempt_at,
    platform_callback_last_attempt_at, platform_callback_completed_at,
    platform_callback_last_error
"""


def _log_job_event(cursor, job_id: str, event_type: str, before: str | None, after: str, payload=None):
    cursor.execute(
        """
        INSERT INTO collection_job_event_logs
            (job_id, worker_id, event_type, before_status, after_status, payload)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (job_id, settings.worker_id, event_type, before, after, Jsonb(payload or {})),
    )


def _heartbeat_sync() -> None:
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO collection_workers
                    (worker_id, worker_name, status, model_name, host_info)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (worker_id) DO UPDATE SET
                    worker_name = EXCLUDED.worker_name,
                    status = EXCLUDED.status,
                    model_name = EXCLUDED.model_name,
                    host_info = EXCLUDED.host_info,
                    last_heartbeat_at = now()
                """,
                (
                    settings.worker_id,
                    WORKER_NAME,
                    "active",
                    settings.ollama_model,
                    Jsonb({"runtime": "integrated", "port": 8200}),
                ),
            )


def _claim_job_sync() -> dict | None:
    lease_seconds = settings.default_lease_seconds
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT job_id, status
                FROM collection_analysis_jobs
                WHERE status IN (%s, %s)
                  AND attempt_count < max_attempts
                ORDER BY priority ASC, created_at ASC
                LIMIT 1
                FOR UPDATE SKIP LOCKED
                """,
                (AnalysisJobStatus.QUEUED.value, AnalysisJobStatus.RETRY_WAIT.value),
            )
            candidate = cursor.fetchone()
            if candidate is None:
                return None

            cursor.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status = %s,
                    claimed_by = %s,
                    attempt_count = attempt_count + 1,
                    lease_expires_at = now() + (%s || ' seconds')::interval,
                    updated_at = now()
                WHERE job_id = %s
                RETURNING {_CALLBACK_JOB_COLUMNS}
                """,
                (
                    AnalysisJobStatus.CLAIMED.value,
                    settings.worker_id,
                    lease_seconds,
                    candidate["job_id"],
                ),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job["job_id"],
                "job_claimed",
                candidate["status"],
                AnalysisJobStatus.CLAIMED.value,
                {"lease_seconds": lease_seconds},
            )
    return job


def _start_job_sync(job_id: str, before_status: str) -> None:
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                UPDATE collection_analysis_jobs
                SET status = %s,
                    claimed_by = %s,
                    updated_at = now()
                WHERE job_id = %s
                """,
                (AnalysisJobStatus.RUNNING.value, settings.worker_id, job_id),
            )
            _log_job_event(
                cursor,
                job_id,
                "job_started",
                before_status,
                AnalysisJobStatus.RUNNING.value,
            )


def _get_audio_asset_sync(asset_id: str) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT asset_id, session_id, project_id, meeting_id, status,
                    storage_uri, file_name, content_type, size_bytes, checksum_sha256,
                    duration_seconds
                FROM collection_audio_assets
                WHERE asset_id = %s
                """,
                (asset_id,),
            )
            return cursor.fetchone()


def _complete_job_sync(job_id: str, model_name: str, result: dict) -> dict:
    from app.routers.collection import _notify_platform_job_completed  # noqa: PLC0415

    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT status
                FROM collection_analysis_jobs
                WHERE job_id = %s
                FOR UPDATE
                """,
                (job_id,),
            )
            current = cursor.fetchone()
            before_status = current["status"] if current else AnalysisJobStatus.RUNNING.value

            cursor.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status = %s,
                    claimed_by = %s,
                    model_name = %s,
                    result_json = %s,
                    platform_callback_status = %s,
                    platform_callback_attempt_count = 0,
                    platform_callback_max_attempts = %s,
                    platform_callback_next_attempt_at = now(),
                    platform_callback_last_attempt_at = NULL,
                    platform_callback_completed_at = NULL,
                    platform_callback_last_error = NULL,
                    updated_at = now(),
                    completed_at = now()
                WHERE job_id = %s
                RETURNING {_CALLBACK_JOB_COLUMNS}
                """,
                (
                    AnalysisJobStatus.COMPLETED.value,
                    settings.worker_id,
                    model_name,
                    Jsonb(result),
                    PlatformCallbackStatus.PENDING.value,
                    settings.platform_callback_max_attempts,
                    job_id,
                ),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job_id,
                "job_completed",
                before_status,
                AnalysisJobStatus.COMPLETED.value,
                {"model_name": model_name},
            )

    # Platform 콜백 즉시 시도 (sync — 이미 to_thread 안에서 실행 중)
    try:
        _notify_platform_job_completed(job)
    except Exception as exc:
        logger.warning("Platform callback failed for %s (will retry): %s", job_id, exc)

    return job


def _fail_job_sync(job_id: str, before_status: str, error_message: str) -> dict:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT attempt_count, max_attempts
                FROM collection_analysis_jobs
                WHERE job_id = %s
                """,
                (job_id,),
            )
            row = cursor.fetchone()
            attempt_count = row["attempt_count"] if row else 1
            max_attempts = row["max_attempts"] if row else settings.max_job_attempts
            next_status = (
                AnalysisJobStatus.RETRY_WAIT.value
                if attempt_count < max_attempts
                else AnalysisJobStatus.FAILED.value
            )

            cursor.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status = %s,
                    claimed_by = NULL,
                    lease_expires_at = NULL,
                    last_error = %s,
                    updated_at = now()
                WHERE job_id = %s
                RETURNING {_CALLBACK_JOB_COLUMNS}
                """,
                (next_status, error_message, job_id),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job_id,
                "job_failed",
                before_status,
                next_status,
                {"error_message": error_message},
            )
    return job


async def run_once() -> None:
    """큐에서 job 하나를 꺼내 STT → LLM 분석 → 완료 처리."""
    await asyncio.to_thread(_heartbeat_sync)

    job = await asyncio.to_thread(_claim_job_sync)
    if not job:
        return  # 처리할 job 없음

    job_id = job["job_id"]
    claimed_status = job["status"]
    logger.info("Claimed analysis job %s", job_id)

    try:
        await asyncio.to_thread(_start_job_sync, job_id, claimed_status)

        transcript = job.get("transcript_text")
        if not transcript:
            asset_id = job.get("asset_id")
            if not asset_id:
                raise RuntimeError("Job has neither transcript_text nor asset_id")
            asset = await asyncio.to_thread(_get_audio_asset_sync, asset_id)
            if not asset:
                raise RuntimeError(f"Audio asset {asset_id} not found")
            storage_uri = asset.get("storage_uri")
            if not storage_uri:
                raise RuntimeError(f"Audio asset {asset_id} has no storage_uri")
            transcript = await transcribe_audio_uri(storage_uri, job.get("language") or "ko")

        model_name, result = await analyze_transcript(transcript)
        await asyncio.to_thread(
            _complete_job_sync,
            job_id,
            model_name,
            result.model_dump(mode="json"),
        )
        logger.info("Completed analysis job %s (model=%s)", job_id, model_name)

    except Exception as exc:
        logger.error("Analysis job %s failed: %s", job_id, exc, exc_info=True)
        try:
            await asyncio.to_thread(_fail_job_sync, job_id, AnalysisJobStatus.RUNNING.value, str(exc))
        except Exception as status_exc:
            logger.error("Failed to mark job %s as failed: %s", job_id, status_exc)
        raise

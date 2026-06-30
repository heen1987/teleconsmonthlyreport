import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import secrets
import time
import uuid

from fastapi import APIRouter, File, Header, HTTPException, Query, UploadFile
import httpx
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.core.config import settings
from app.db.session import get_connection
from app.domain.statuses import (
    AnalysisJobStatus,
    AudioAssetStatus,
    PlatformCallbackStatus,
    UploadSessionStatus,
)
from app.schemas import (
    AnalysisJobCreate,
    AnalysisJobOut,
    AudioAssetCreate,
    AudioAssetOut,
    ClaimJobRequest,
    JobStatusUpdate,
    UploadSessionCreate,
    UploadSessionOut,
    WorkerHeartbeat,
)

router = APIRouter(tags=["collection"])

JOB_RETURN_COLUMNS = """
    job_id, session_id, asset_id, project_id, meeting_id, status,
    transcript_text, language, claimed_by, lease_expires_at, model_name,
    result_json, attempt_count, max_attempts
"""

CALLBACK_JOB_RETURN_COLUMNS = """
    job_id, session_id, asset_id, project_id, meeting_id, status,
    transcript_text, language, claimed_by, lease_expires_at, model_name,
    result_json, attempt_count, max_attempts,
    platform_callback_status, platform_callback_attempt_count,
    platform_callback_max_attempts, platform_callback_next_attempt_at,
    platform_callback_last_attempt_at, platform_callback_completed_at,
    platform_callback_last_error
"""


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _safe_file_name(file_name: str | None) -> str:
    fallback = "meeting-audio.bin"
    name = Path(file_name or fallback).name
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")
    return cleaned or fallback


def _storage_root() -> Path:
    root = Path(settings.audio_storage_dir)
    if not root.is_absolute():
        root = Path(__file__).resolve().parents[3] / root
    root.mkdir(parents=True, exist_ok=True)
    return root


def _log_job_event(cursor, job_id: str, worker_id: str | None, event_type: str, before: str | None, after: str, payload=None):
    cursor.execute(
        """
        INSERT INTO collection_job_event_logs
            (job_id, worker_id, event_type, before_status, after_status, payload)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (job_id, worker_id, event_type, before, after, Jsonb(payload or {})),
    )


def _get_audio_storage_uri(asset_id: str | None) -> str | None:
    if not asset_id:
        return None
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT storage_uri
                FROM collection_audio_assets
                WHERE asset_id = %s
                """,
                (asset_id,),
            )
            asset = cursor.fetchone()
    return asset["storage_uri"] if asset else None


def _record_callback_event(job_id: str, event_type: str, payload: dict):
    with get_connection() as connection:
        with connection.cursor() as cursor:
            _log_job_event(
                cursor,
                job_id,
                None,
                event_type,
                AnalysisJobStatus.COMPLETED.value,
                AnalysisJobStatus.COMPLETED.value,
                payload,
            )


def _json_or_text(response: httpx.Response):
    try:
        return response.json()
    except ValueError:
        return response.text


def _callback_backoff_seconds(failed_attempt_count: int) -> int:
    exponent = max(failed_attempt_count - 1, 0)
    delay = settings.platform_callback_base_backoff_seconds * (2**exponent)
    return min(delay, settings.platform_callback_max_backoff_seconds)


def _isoformat(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _canonical_callback_body(body: dict) -> str:
    return json.dumps(
        body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _callback_headers(raw_body: bytes, job_id: str) -> dict[str, str]:
    timestamp = str(int(time.time()))
    signed_payload = timestamp.encode("utf-8") + b"." + raw_body
    digest = hmac.new(
        settings.platform_callback_secret.encode("utf-8"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()
    return {
        "Content-Type": "application/json",
        "X-Collection-Key-Id": settings.platform_callback_secret_id,
        "X-Collection-Timestamp": timestamp,
        "X-Collection-Signature": f"sha256={digest}",
        "X-Collection-Job-Id": job_id,
    }


def _callback_body(job: dict) -> dict:
    return {
        "job_id": job["job_id"],
        "project_id": job["project_id"],
        "meeting_id": job["meeting_id"],
        "asset_id": job.get("asset_id"),
        "audio_path": _get_audio_storage_uri(job.get("asset_id")),
        "transcript": job.get("transcript_text"),
        "model_name": job.get("model_name") or "unknown",
        "result": job["result_json"],
    }


def _mark_platform_callback_disabled(job_id: str) -> dict:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_next_attempt_at = NULL,
                    platform_callback_last_error = NULL,
                    updated_at = now()
                WHERE job_id = %s
                """,
                (PlatformCallbackStatus.DISABLED.value, job_id),
            )
            _log_job_event(
                cursor,
                job_id,
                None,
                "platform_callback_disabled",
                AnalysisJobStatus.COMPLETED.value,
                AnalysisJobStatus.COMPLETED.value,
                {"reason": "PLATFORM_CALLBACK_ENABLED=false"},
            )
    return {"job_id": job_id, "status": PlatformCallbackStatus.DISABLED.value}


def _claim_platform_callback_attempt(job_id: str, *, force: bool = False) -> dict | None:
    filters = ""
    params: list = [
        PlatformCallbackStatus.SENDING.value,
        job_id,
        AnalysisJobStatus.COMPLETED.value,
    ]
    if not force:
        filters = """
          AND platform_callback_status IN (%s, %s)
          AND platform_callback_attempt_count < platform_callback_max_attempts
          AND (
              platform_callback_next_attempt_at IS NULL
              OR platform_callback_next_attempt_at <= now()
          )
        """
        params.extend(
            [
                PlatformCallbackStatus.PENDING.value,
                PlatformCallbackStatus.RETRY_WAIT.value,
            ]
        )

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_attempt_count = platform_callback_attempt_count + 1,
                    platform_callback_last_attempt_at = now(),
                    platform_callback_next_attempt_at = NULL,
                    platform_callback_last_error = NULL,
                    updated_at = now()
                WHERE job_id = %s
                  AND status = %s
                  AND result_json IS NOT NULL
                  {filters}
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                tuple(params),
            )
            return cursor.fetchone()


def _mark_platform_callback_succeeded(job: dict, callback_url: str, response: httpx.Response, trigger: str) -> dict:
    response_body = _json_or_text(response)
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_next_attempt_at = NULL,
                    platform_callback_completed_at = now(),
                    platform_callback_last_error = NULL,
                    updated_at = now()
                WHERE job_id = %s
                """,
                (PlatformCallbackStatus.SUCCEEDED.value, job["job_id"]),
            )
            _log_job_event(
                cursor,
                job["job_id"],
                None,
                "platform_callback_succeeded",
                AnalysisJobStatus.COMPLETED.value,
                AnalysisJobStatus.COMPLETED.value,
                {
                    "attempt": job["platform_callback_attempt_count"],
                    "callback_url": callback_url,
                    "response": response_body,
                    "trigger": trigger,
                },
            )
    return {
        "job_id": job["job_id"],
        "status": PlatformCallbackStatus.SUCCEEDED.value,
        "attempt": job["platform_callback_attempt_count"],
        "response": response_body,
    }


def _mark_platform_callback_failed(job: dict, callback_url: str, error_message: str, trigger: str) -> dict:
    attempt = job["platform_callback_attempt_count"]
    max_attempts = job["platform_callback_max_attempts"]
    exhausted = attempt >= max_attempts
    next_status = (
        PlatformCallbackStatus.FAILED.value
        if exhausted
        else PlatformCallbackStatus.RETRY_WAIT.value
    )
    next_attempt_at = None
    if not exhausted:
        next_attempt_at = datetime.now(timezone.utc) + timedelta(seconds=_callback_backoff_seconds(attempt))

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_next_attempt_at = %s,
                    platform_callback_last_error = %s,
                    updated_at = now()
                WHERE job_id = %s
                """,
                (next_status, next_attempt_at, error_message, job["job_id"]),
            )
            _log_job_event(
                cursor,
                job["job_id"],
                None,
                "platform_callback_failed",
                AnalysisJobStatus.COMPLETED.value,
                AnalysisJobStatus.COMPLETED.value,
                {
                    "attempt": attempt,
                    "max_attempts": max_attempts,
                    "callback_url": callback_url,
                    "error_message": error_message,
                    "next_status": next_status,
                    "next_attempt_at": _isoformat(next_attempt_at),
                    "trigger": trigger,
                },
            )
    return {
        "job_id": job["job_id"],
        "status": next_status,
        "attempt": attempt,
        "max_attempts": max_attempts,
        "next_attempt_at": _isoformat(next_attempt_at),
        "error_message": error_message,
    }


def _notify_platform_job_completed(job: dict, *, trigger: str = "completion", force: bool = False) -> dict:
    if not job.get("result_json"):
        return {"job_id": job["job_id"], "status": "skipped", "reason": "missing result_json"}
    if not settings.platform_callback_enabled:
        return _mark_platform_callback_disabled(job["job_id"])

    claimed = _claim_platform_callback_attempt(job["job_id"], force=force)
    if claimed is None:
        return {
            "job_id": job["job_id"],
            "status": "skipped",
            "reason": "callback is not due, already succeeded, or attempts exhausted",
        }

    callback_url = (
        f"{settings.platform_api_url.rstrip('/')}"
        f"/integrations/collection/jobs/{job['job_id']}/complete"
    )
    body = _callback_body(claimed)
    raw_body = _canonical_callback_body(body).encode("utf-8")
    try:
        response = httpx.post(
            callback_url,
            content=raw_body,
            headers=_callback_headers(raw_body, job["job_id"]),
            timeout=settings.platform_callback_timeout_seconds,
        )
        response.raise_for_status()
        return _mark_platform_callback_succeeded(claimed, callback_url, response, trigger)
    except Exception as exc:
        return _mark_platform_callback_failed(claimed, callback_url, str(exc), trigger)


def _due_platform_callback_jobs(limit: int) -> list[dict]:
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {CALLBACK_JOB_RETURN_COLUMNS}
                FROM collection_analysis_jobs
                WHERE status = %s
                  AND result_json IS NOT NULL
                  AND platform_callback_status IN (%s, %s)
                  AND platform_callback_attempt_count < platform_callback_max_attempts
                  AND (
                      platform_callback_next_attempt_at IS NULL
                      OR platform_callback_next_attempt_at <= now()
                  )
                ORDER BY COALESCE(platform_callback_next_attempt_at, completed_at, updated_at) ASC
                LIMIT %s
                """,
                (
                    AnalysisJobStatus.COMPLETED.value,
                    PlatformCallbackStatus.PENDING.value,
                    PlatformCallbackStatus.RETRY_WAIT.value,
                    limit,
                ),
            )
            return cursor.fetchall()


def retry_due_platform_callbacks_once(limit: int | None = None) -> dict:
    batch_limit = limit or settings.platform_callback_retry_batch_size
    jobs = _due_platform_callback_jobs(batch_limit)
    results = [
        _notify_platform_job_completed(job, trigger="automatic_retry")
        for job in jobs
    ]
    retried = sum(1 for result in results if result["status"] != "skipped")
    return {"scanned": len(jobs), "retried": retried, "results": results}


@router.post("/upload-sessions", response_model=UploadSessionOut)
def create_upload_session(payload: UploadSessionCreate):
    session_id = f"UPL-{uuid.uuid4().hex[:12]}"
    upload_token = secrets.token_urlsafe(32)
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                INSERT INTO collection_upload_sessions
                    (
                        session_id,
                        project_id,
                        meeting_id,
                        requested_by,
                        file_name,
                        content_type,
                        expected_size_bytes,
                        checksum_sha256,
                        upload_token_hash,
                        expires_at
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING session_id, project_id, meeting_id, status, expires_at
                """,
                (
                    session_id,
                    payload.project_id,
                    payload.meeting_id,
                    payload.requested_by,
                    payload.file_name,
                    payload.content_type,
                    payload.expected_size_bytes,
                    payload.checksum_sha256,
                    _token_hash(upload_token),
                    payload.expires_at,
                ),
            )
            row = cursor.fetchone()
    return UploadSessionOut(**row, upload_token=upload_token)


@router.post("/upload-sessions/{session_id}/audio-file", response_model=AudioAssetOut)
async def upload_audio_file(
    session_id: str,
    file: UploadFile = File(...),
    x_upload_token: str = Header(..., alias="X-Upload-Token"),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT session_id, project_id, meeting_id, file_name, content_type,
                    expected_size_bytes, checksum_sha256, upload_token_hash
                FROM collection_upload_sessions
                WHERE session_id = %s
                """,
                (session_id,),
            )
            session = cursor.fetchone()
    if session is None:
        raise HTTPException(status_code=404, detail="Upload session not found")
    if _token_hash(x_upload_token) != session["upload_token_hash"]:
        raise HTTPException(status_code=403, detail="Invalid upload token")

    asset_id = f"AUD-{uuid.uuid4().hex[:12]}"
    file_name = _safe_file_name(file.filename or session["file_name"])
    asset_dir = _storage_root() / session_id
    asset_dir.mkdir(parents=True, exist_ok=True)
    target_path = asset_dir / f"{asset_id}-{file_name}"

    digest = hashlib.sha256()
    size_bytes = 0
    with target_path.open("wb") as target:
        while chunk := await file.read(1024 * 1024):
            size_bytes += len(chunk)
            digest.update(chunk)
            target.write(chunk)
    checksum = digest.hexdigest()

    if session["expected_size_bytes"] is not None and size_bytes != session["expected_size_bytes"]:
        target_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="Uploaded file size does not match expected_size_bytes")
    if session["checksum_sha256"] and checksum != session["checksum_sha256"]:
        target_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="Uploaded file checksum does not match checksum_sha256")

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                INSERT INTO collection_audio_assets
                    (
                        asset_id,
                        session_id,
                        project_id,
                        meeting_id,
                        storage_uri,
                        file_name,
                        content_type,
                        size_bytes,
                        checksum_sha256,
                        status
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING asset_id, session_id, project_id, meeting_id, status,
                    storage_uri, file_name, content_type, size_bytes, checksum_sha256,
                    duration_seconds
                """,
                (
                    asset_id,
                    session_id,
                    session["project_id"],
                    session["meeting_id"],
                    target_path.resolve().as_uri(),
                    file_name,
                    file.content_type or session["content_type"],
                    size_bytes,
                    checksum,
                    AudioAssetStatus.STORED.value,
                ),
            )
            asset = cursor.fetchone()
            cursor.execute(
                """
                UPDATE collection_upload_sessions
                SET status = %s, updated_at = now()
                WHERE session_id = %s
                """,
                (UploadSessionStatus.READY.value, session_id),
            )
    return asset


@router.post("/audio-assets", response_model=AudioAssetOut)
def register_audio_asset(payload: AudioAssetCreate):
    asset_id = f"AUD-{uuid.uuid4().hex[:12]}"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT project_id, meeting_id
                FROM collection_upload_sessions
                WHERE session_id = %s
                """,
                (payload.session_id,),
            )
            session = cursor.fetchone()
            if session is None:
                raise HTTPException(status_code=404, detail="Upload session not found")

            cursor.execute(
                """
                INSERT INTO collection_audio_assets
                    (
                        asset_id,
                        session_id,
                        project_id,
                        meeting_id,
                        storage_uri,
                        file_name,
                        content_type,
                        size_bytes,
                        checksum_sha256,
                        duration_seconds,
                        status
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING asset_id, session_id, project_id, meeting_id, status
                    , storage_uri, file_name, content_type, size_bytes, checksum_sha256,
                    duration_seconds
                """,
                (
                    asset_id,
                    payload.session_id,
                    session["project_id"],
                    session["meeting_id"],
                    payload.storage_uri,
                    payload.file_name,
                    payload.content_type,
                    payload.size_bytes,
                    payload.checksum_sha256,
                    payload.duration_seconds,
                    AudioAssetStatus.VALIDATED.value,
                ),
            )
            asset = cursor.fetchone()
            cursor.execute(
                """
                UPDATE collection_upload_sessions
                SET status = %s, updated_at = now()
                WHERE session_id = %s
                """,
                (UploadSessionStatus.READY.value, payload.session_id),
            )
    return asset


@router.get("/audio-assets/{asset_id}", response_model=AudioAssetOut)
def get_audio_asset(asset_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
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
            asset = cursor.fetchone()
    if asset is None:
        raise HTTPException(status_code=404, detail="Audio asset not found")
    return asset


@router.post("/analysis-jobs", response_model=AnalysisJobOut)
def create_analysis_job(payload: AnalysisJobCreate):
    job_id = f"CJOB-{uuid.uuid4().hex[:12]}"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT project_id, meeting_id
                FROM collection_upload_sessions
                WHERE session_id = %s
                """,
                (payload.session_id,),
            )
            session = cursor.fetchone()
            if session is None:
                raise HTTPException(status_code=404, detail="Upload session not found")

            cursor.execute(
                f"""
                INSERT INTO collection_analysis_jobs
                    (
                        job_id,
                        session_id,
                        asset_id,
                        project_id,
                        meeting_id,
                        transcript_text,
                        language,
                        status,
                        priority,
                        max_attempts
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                (
                    job_id,
                    payload.session_id,
                    payload.asset_id,
                    session["project_id"],
                    session["meeting_id"],
                    payload.transcript_text,
                    payload.language,
                    AnalysisJobStatus.QUEUED.value,
                    payload.priority,
                    settings.max_job_attempts,
                ),
            )
            job = cursor.fetchone()
            _log_job_event(cursor, job_id, None, "job_created", None, AnalysisJobStatus.QUEUED.value)
    return job


@router.get("/analysis-jobs", response_model=list[AnalysisJobOut])
def list_analysis_jobs(status: str | None = None, meeting_id: str | None = None):
    query = f"""
        SELECT {CALLBACK_JOB_RETURN_COLUMNS}
        FROM collection_analysis_jobs
    """
    filters = []
    params: list[str] = []
    if status:
        filters.append("status = %s")
        params.append(status)
    if meeting_id:
        filters.append("meeting_id = %s")
        params.append(meeting_id)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, tuple(params))
            rows = cursor.fetchall()
    return rows


@router.get("/analysis-jobs/{job_id}/events")
def list_analysis_job_events(job_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT event_id, job_id, worker_id, event_type, before_status,
                    after_status, payload, created_at
                FROM collection_job_event_logs
                WHERE job_id = %s
                ORDER BY created_at ASC
                """,
                (job_id,),
            )
            rows = cursor.fetchall()
    return rows


@router.get("/analysis-jobs/{job_id}", response_model=AnalysisJobOut)
def get_analysis_job(job_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {CALLBACK_JOB_RETURN_COLUMNS}
                FROM collection_analysis_jobs
                WHERE job_id = %s
                """,
                (job_id,),
            )
            row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Analysis job not found")
    return row


@router.post("/analysis-jobs/callbacks/retry-due")
def retry_due_platform_callbacks(limit: int = Query(default=20, ge=1, le=100)):
    return retry_due_platform_callbacks_once(limit)


@router.post("/analysis-jobs/{job_id}/notify-platform")
def replay_platform_notification(job_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {CALLBACK_JOB_RETURN_COLUMNS}
                FROM collection_analysis_jobs
                WHERE job_id = %s
                """,
                (job_id,),
            )
            job = cursor.fetchone()
    if job is None:
        raise HTTPException(status_code=404, detail="Analysis job not found")
    if job["status"] != AnalysisJobStatus.COMPLETED.value:
        raise HTTPException(status_code=409, detail="Only completed jobs can notify Platform")
    if not job.get("result_json"):
        raise HTTPException(status_code=409, detail="Completed job has no result_json")

    callback = _notify_platform_job_completed(job, trigger="manual_replay", force=True)
    return {"job_id": job_id, "status": "platform_notification_requested", "callback": callback}


@router.post("/analysis-jobs/requeue-expired")
def requeue_expired_jobs():
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT job_id, status, claimed_by
                FROM collection_analysis_jobs
                WHERE status IN (%s, %s)
                  AND lease_expires_at IS NOT NULL
                  AND lease_expires_at < now()
                FOR UPDATE
                """,
                (AnalysisJobStatus.CLAIMED.value, AnalysisJobStatus.RUNNING.value),
            )
            expired = cursor.fetchall()
            for job in expired:
                cursor.execute(
                    """
                    UPDATE collection_analysis_jobs
                    SET status = %s,
                        claimed_by = NULL,
                        lease_expires_at = NULL,
                        updated_at = now()
                    WHERE job_id = %s
                    """,
                    (AnalysisJobStatus.RETRY_WAIT.value, job["job_id"]),
                )
                _log_job_event(
                    cursor,
                    job["job_id"],
                    job["claimed_by"],
                    "lease_expired",
                    job["status"],
                    AnalysisJobStatus.RETRY_WAIT.value,
                )
    return {"requeued": len(expired)}


@router.post("/workers/heartbeat")
def heartbeat(payload: WorkerHeartbeat):
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO collection_workers
                    (worker_id, worker_name, status, current_job_id, model_name, host_info)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (worker_id)
                DO UPDATE SET
                    worker_name = EXCLUDED.worker_name,
                    status = EXCLUDED.status,
                    current_job_id = EXCLUDED.current_job_id,
                    model_name = EXCLUDED.model_name,
                    host_info = EXCLUDED.host_info,
                    last_heartbeat_at = now()
                """,
                (
                    payload.worker_id,
                    payload.worker_name,
                    payload.status,
                    payload.current_job_id,
                    payload.model_name,
                    Jsonb(payload.host_info),
                ),
            )
    return {"worker_id": payload.worker_id, "status": "ok"}


@router.post("/analysis-jobs/claim", response_model=AnalysisJobOut | None)
def claim_analysis_job(payload: ClaimJobRequest):
    lease_seconds = payload.lease_seconds or settings.default_lease_seconds
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
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
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                (
                    AnalysisJobStatus.CLAIMED.value,
                    payload.worker_id,
                    lease_seconds,
                    candidate["job_id"],
                ),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job["job_id"],
                payload.worker_id,
                "job_claimed",
                candidate["status"],
                AnalysisJobStatus.CLAIMED.value,
                {"lease_seconds": lease_seconds},
            )
    return job


@router.post("/analysis-jobs/{job_id}/start", response_model=AnalysisJobOut)
def start_job(job_id: str, payload: JobStatusUpdate):
    return _set_job_status(job_id, payload, AnalysisJobStatus.RUNNING.value, "job_started")


@router.post("/analysis-jobs/{job_id}/complete", response_model=AnalysisJobOut)
def complete_job(job_id: str, payload: JobStatusUpdate):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
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
            if current is None:
                raise HTTPException(status_code=404, detail="Analysis job not found")
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
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                (
                    AnalysisJobStatus.COMPLETED.value,
                    payload.worker_id,
                    payload.payload.get("model_name"),
                    Jsonb(payload.payload.get("result")),
                    PlatformCallbackStatus.PENDING.value,
                    settings.platform_callback_max_attempts,
                    job_id,
                ),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job_id,
                payload.worker_id,
                "job_completed",
                current["status"],
                AnalysisJobStatus.COMPLETED.value,
                {"model_name": payload.payload.get("model_name")},
            )
    _notify_platform_job_completed(job)
    return job


@router.post("/analysis-jobs/{job_id}/fail", response_model=AnalysisJobOut)
def fail_job(job_id: str, payload: JobStatusUpdate):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT status, attempt_count, max_attempts
                FROM collection_analysis_jobs
                WHERE job_id = %s
                FOR UPDATE
                """,
                (job_id,),
            )
            current = cursor.fetchone()
            if current is None:
                raise HTTPException(status_code=404, detail="Analysis job not found")
            next_status = (
                AnalysisJobStatus.RETRY_WAIT.value
                if current["attempt_count"] < current["max_attempts"]
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
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                (next_status, payload.error_message, job_id),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job_id,
                payload.worker_id,
                "job_failed",
                current["status"],
                next_status,
                {"error_message": payload.error_message, **payload.payload},
            )
    return job


def _set_job_status(
    job_id: str,
    payload: JobStatusUpdate,
    next_status: str,
    event_type: str,
    completed: bool = False,
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
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
            if current is None:
                raise HTTPException(status_code=404, detail="Analysis job not found")

            completed_sql = ", completed_at = now()" if completed else ""
            cursor.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status = %s,
                    claimed_by = %s,
                    updated_at = now()
                    {completed_sql}
                WHERE job_id = %s
                RETURNING {CALLBACK_JOB_RETURN_COLUMNS}
                """,
                (next_status, payload.worker_id, job_id),
            )
            job = cursor.fetchone()
            _log_job_event(
                cursor,
                job_id,
                payload.worker_id,
                event_type,
                current["status"],
                next_status,
                payload.payload,
            )
    return job

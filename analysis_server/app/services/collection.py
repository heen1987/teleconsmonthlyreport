"""
Collection 서비스 모듈

HTTP 엔드포인트 없이 순수 Python 함수로 구성된 내부 모듈.
- 업로드 세션 / 오디오 에셋 / 분석 Job CRUD
- 워커 heartbeat / claim / complete / fail (내부 asyncio 워커 전용)
- Platform API HMAC 콜백 전송

라우터(`app/routers/upload.py`)와 분석 워커(`app/services/analysis_worker.py`)
양쪽에서 임포트해서 사용한다.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

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

# ── SQL 컬럼 셋 ──────────────────────────────────────────────────────────────

_JOB_COLS = """
    job_id, session_id, asset_id, project_id, meeting_id, status,
    transcript_text, language, claimed_by, lease_expires_at, model_name,
    result_json, attempt_count, max_attempts,
    platform_callback_status, platform_callback_attempt_count,
    platform_callback_max_attempts, platform_callback_next_attempt_at,
    platform_callback_last_attempt_at, platform_callback_completed_at,
    platform_callback_last_error
"""


# ────────────────────────────────────────────────────────────────────────────
# 내부 유틸
# ────────────────────────────────────────────────────────────────────────────

def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _safe_filename(name: str | None) -> str:
    fallback = "meeting-audio.bin"
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", Path(name or fallback).name).strip("._")
    return cleaned or fallback


def _storage_root() -> Path:
    root = Path(settings.audio_storage_dir)
    if not root.is_absolute():
        root = Path(__file__).resolve().parents[3] / root
    root.mkdir(parents=True, exist_ok=True)
    return root


def _log_event(cursor, job_id: str, worker_id: str | None, event_type: str,
               before: str | None, after: str, payload: dict | None = None) -> None:
    cursor.execute(
        """
        INSERT INTO collection_job_event_logs
            (job_id, worker_id, event_type, before_status, after_status, payload)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (job_id, worker_id, event_type, before, after, Jsonb(payload or {})),
    )


# ────────────────────────────────────────────────────────────────────────────
# Platform API 콜백 (내부 전용)
# ────────────────────────────────────────────────────────────────────────────

def _callback_backoff(attempt: int) -> int:
    delay = settings.platform_callback_base_backoff_seconds * (2 ** max(attempt - 1, 0))
    return min(delay, settings.platform_callback_max_backoff_seconds)


def _canonical(body: dict) -> bytes:
    return json.dumps(body, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode()


def _callback_headers(raw: bytes, job_id: str) -> dict[str, str]:
    ts = str(int(time.time()))
    sig = hmac.new(
        settings.platform_callback_secret.encode(),
        ts.encode() + b"." + raw,
        hashlib.sha256,
    ).hexdigest()
    return {
        "Content-Type": "application/json",
        "X-Collection-Key-Id": settings.platform_callback_secret_id,
        "X-Collection-Timestamp": ts,
        "X-Collection-Signature": f"sha256={sig}",
        "X-Collection-Job-Id": job_id,
    }


def _storage_uri_for_asset(asset_id: str | None) -> str | None:
    if not asset_id:
        return None
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT storage_uri FROM collection_audio_assets WHERE asset_id = %s",
                (asset_id,),
            )
            row = cur.fetchone()
    return row["storage_uri"] if row else None


def _callback_body(job: dict) -> dict:
    return {
        "job_id": job["job_id"],
        "project_id": job["project_id"],
        "meeting_id": job["meeting_id"],
        "asset_id": job.get("asset_id"),
        "audio_path": _storage_uri_for_asset(job.get("asset_id")),
        "transcript": job.get("transcript_text"),
        "model_name": job.get("model_name") or "unknown",
        "result": job["result_json"],
    }


def _claim_callback_slot(job_id: str, *, force: bool) -> dict | None:
    extra = ""
    params: list = [PlatformCallbackStatus.SENDING.value, job_id,
                    AnalysisJobStatus.COMPLETED.value]
    if not force:
        extra = """
          AND platform_callback_status IN (%s, %s)
          AND platform_callback_attempt_count < platform_callback_max_attempts
          AND (platform_callback_next_attempt_at IS NULL
               OR platform_callback_next_attempt_at <= now())
        """
        params.extend([PlatformCallbackStatus.PENDING.value,
                       PlatformCallbackStatus.RETRY_WAIT.value])
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_attempt_count = platform_callback_attempt_count + 1,
                    platform_callback_last_attempt_at = now(),
                    platform_callback_next_attempt_at = NULL,
                    platform_callback_last_error = NULL,
                    updated_at = now()
                WHERE job_id = %s AND status = %s AND result_json IS NOT NULL {extra}
                RETURNING {_JOB_COLS}
                """,
                tuple(params),
            )
            return cur.fetchone()


def _mark_callback_ok(job: dict, url: str, resp: httpx.Response, trigger: str) -> dict:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
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
            _log_event(cur, job["job_id"], None, "platform_callback_succeeded",
                       AnalysisJobStatus.COMPLETED.value,
                       AnalysisJobStatus.COMPLETED.value,
                       {"attempt": job["platform_callback_attempt_count"],
                        "url": url, "trigger": trigger})
    return {"job_id": job["job_id"],
            "status": PlatformCallbackStatus.SUCCEEDED.value,
            "attempt": job["platform_callback_attempt_count"]}


def _mark_callback_fail(job: dict, url: str, error: str, trigger: str) -> dict:
    attempt = job["platform_callback_attempt_count"]
    exhausted = attempt >= job["platform_callback_max_attempts"]
    next_status = (PlatformCallbackStatus.FAILED.value if exhausted
                   else PlatformCallbackStatus.RETRY_WAIT.value)
    next_at = (None if exhausted
               else datetime.now(timezone.utc) + timedelta(seconds=_callback_backoff(attempt)))
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE collection_analysis_jobs
                SET platform_callback_status = %s,
                    platform_callback_next_attempt_at = %s,
                    platform_callback_last_error = %s,
                    updated_at = now()
                WHERE job_id = %s
                """,
                (next_status, next_at, error, job["job_id"]),
            )
            _log_event(cur, job["job_id"], None, "platform_callback_failed",
                       AnalysisJobStatus.COMPLETED.value,
                       AnalysisJobStatus.COMPLETED.value,
                       {"attempt": attempt, "url": url, "error": error,
                        "next_status": next_status, "trigger": trigger})
    return {"job_id": job["job_id"], "status": next_status,
            "attempt": attempt, "error": error}


def notify_platform_job_completed(job: dict, *, trigger: str = "completion",
                                   force: bool = False) -> dict:
    """완료된 job 을 Platform API 에 HMAC 서명으로 콜백 전송한다."""
    if not job.get("result_json"):
        return {"job_id": job["job_id"], "status": "skipped", "reason": "missing result_json"}
    if not settings.platform_callback_enabled:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE collection_analysis_jobs
                    SET platform_callback_status = %s, updated_at = now()
                    WHERE job_id = %s
                    """,
                    (PlatformCallbackStatus.DISABLED.value, job["job_id"]),
                )
        return {"job_id": job["job_id"], "status": PlatformCallbackStatus.DISABLED.value}

    claimed = _claim_callback_slot(job["job_id"], force=force)
    if claimed is None:
        return {"job_id": job["job_id"], "status": "skipped",
                "reason": "not due, already succeeded, or exhausted"}

    url = (f"{settings.platform_api_url.rstrip('/')}"
           f"/integrations/collection/jobs/{job['job_id']}/complete")
    body = _callback_body(claimed)
    raw = _canonical(body)
    try:
        resp = httpx.post(url, content=raw,
                          headers=_callback_headers(raw, job["job_id"]),
                          timeout=settings.platform_callback_timeout_seconds)
        resp.raise_for_status()
        return _mark_callback_ok(claimed, url, resp, trigger)
    except Exception as exc:
        return _mark_callback_fail(claimed, url, str(exc), trigger)


def retry_due_callbacks(limit: int | None = None) -> dict:
    batch = limit or settings.platform_callback_retry_batch_size
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT {_JOB_COLS}
                FROM collection_analysis_jobs
                WHERE status = %s AND result_json IS NOT NULL
                  AND platform_callback_status IN (%s, %s)
                  AND platform_callback_attempt_count < platform_callback_max_attempts
                  AND (platform_callback_next_attempt_at IS NULL
                       OR platform_callback_next_attempt_at <= now())
                ORDER BY COALESCE(platform_callback_next_attempt_at, completed_at,
                                  updated_at) ASC
                LIMIT %s
                """,
                (AnalysisJobStatus.COMPLETED.value,
                 PlatformCallbackStatus.PENDING.value,
                 PlatformCallbackStatus.RETRY_WAIT.value,
                 batch),
            )
            jobs = cur.fetchall()
    results = [notify_platform_job_completed(j, trigger="auto_retry") for j in jobs]
    retried = sum(1 for r in results if r["status"] != "skipped")
    return {"scanned": len(jobs), "retried": retried, "results": results}


# ────────────────────────────────────────────────────────────────────────────
# 업로드 세션
# ────────────────────────────────────────────────────────────────────────────

def create_upload_session(project_id: str, meeting_id: str,
                           requested_by: str | None = None,
                           file_name: str | None = None,
                           content_type: str | None = None,
                           expected_size_bytes: int | None = None,
                           checksum_sha256: str | None = None,
                           expires_at: datetime | None = None) -> dict:
    session_id = f"UPL-{uuid.uuid4().hex[:12]}"
    token = secrets.token_urlsafe(32)
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                INSERT INTO collection_upload_sessions
                    (session_id, project_id, meeting_id, requested_by,
                     file_name, content_type, expected_size_bytes,
                     checksum_sha256, upload_token_hash, expires_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING session_id, project_id, meeting_id, status, expires_at
                """,
                (session_id, project_id, meeting_id, requested_by,
                 file_name, content_type, expected_size_bytes,
                 checksum_sha256, _token_hash(token), expires_at),
            )
            row = dict(cur.fetchone())
    row["upload_token"] = token
    return row


def get_upload_session(session_id: str) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT session_id, project_id, meeting_id, file_name, content_type,
                    expected_size_bytes, checksum_sha256, upload_token_hash
                FROM collection_upload_sessions WHERE session_id = %s
                """,
                (session_id,),
            )
            return cur.fetchone()


# ────────────────────────────────────────────────────────────────────────────
# 오디오 에셋
# ────────────────────────────────────────────────────────────────────────────

def store_audio_file(session_id: str, upload_token: str,
                     content: bytes, filename: str | None,
                     mime: str | None) -> dict:
    """파일 바이트를 받아 디스크에 저장 후 audio_asset 행 생성."""
    session = get_upload_session(session_id)
    if session is None:
        raise ValueError(f"Upload session not found: {session_id}")
    if _token_hash(upload_token) != session["upload_token_hash"]:
        raise PermissionError("Invalid upload token")

    asset_id = f"AUD-{uuid.uuid4().hex[:12]}"
    safe_name = _safe_filename(filename or session["file_name"])
    dest = _storage_root() / session_id
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / f"{asset_id}-{safe_name}"

    digest = hashlib.sha256(content)
    checksum = digest.hexdigest()
    size = len(content)
    target.write_bytes(content)

    if session["expected_size_bytes"] is not None and size != session["expected_size_bytes"]:
        target.unlink(missing_ok=True)
        raise ValueError("File size mismatch")
    if session["checksum_sha256"] and checksum != session["checksum_sha256"]:
        target.unlink(missing_ok=True)
        raise ValueError("Checksum mismatch")

    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                INSERT INTO collection_audio_assets
                    (asset_id, session_id, project_id, meeting_id,
                     storage_uri, file_name, content_type,
                     size_bytes, checksum_sha256, status)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING asset_id, session_id, project_id, meeting_id, status,
                    storage_uri, file_name, content_type, size_bytes,
                    checksum_sha256, duration_seconds
                """,
                (asset_id, session_id,
                 session["project_id"], session["meeting_id"],
                 target.resolve().as_uri(), safe_name, mime,
                 size, checksum, AudioAssetStatus.STORED.value),
            )
            asset = dict(cur.fetchone())
            cur.execute(
                "UPDATE collection_upload_sessions SET status=%s, updated_at=now() WHERE session_id=%s",
                (UploadSessionStatus.READY.value, session_id),
            )
    return asset


def register_audio_asset(session_id: str, storage_uri: str,
                          file_name: str | None = None,
                          content_type: str | None = None,
                          size_bytes: int | None = None,
                          checksum_sha256: str | None = None,
                          duration_seconds: float | None = None) -> dict:
    """이미 저장된 파일의 URI 를 등록 (외부 저장소 연동 시)."""
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT project_id, meeting_id FROM collection_upload_sessions WHERE session_id=%s",
                (session_id,),
            )
            session = cur.fetchone()
            if session is None:
                raise ValueError(f"Upload session not found: {session_id}")

            asset_id = f"AUD-{uuid.uuid4().hex[:12]}"
            cur.execute(
                """
                INSERT INTO collection_audio_assets
                    (asset_id, session_id, project_id, meeting_id,
                     storage_uri, file_name, content_type,
                     size_bytes, checksum_sha256, duration_seconds, status)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING asset_id, session_id, project_id, meeting_id, status,
                    storage_uri, file_name, content_type, size_bytes,
                    checksum_sha256, duration_seconds
                """,
                (asset_id, session_id,
                 session["project_id"], session["meeting_id"],
                 storage_uri, file_name, content_type,
                 size_bytes, checksum_sha256, duration_seconds,
                 AudioAssetStatus.VALIDATED.value),
            )
            asset = dict(cur.fetchone())
            cur.execute(
                "UPDATE collection_upload_sessions SET status=%s, updated_at=now() WHERE session_id=%s",
                (UploadSessionStatus.READY.value, session_id),
            )
    return asset


def get_audio_asset(asset_id: str) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT asset_id, session_id, project_id, meeting_id, status,
                    storage_uri, file_name, content_type, size_bytes,
                    checksum_sha256, duration_seconds
                FROM collection_audio_assets WHERE asset_id = %s
                """,
                (asset_id,),
            )
            return cur.fetchone()


# ────────────────────────────────────────────────────────────────────────────
# 분석 Job
# ────────────────────────────────────────────────────────────────────────────

def create_analysis_job(session_id: str, asset_id: str | None = None,
                         transcript_text: str | None = None,
                         language: str = "ko", priority: int = 100) -> dict:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT project_id, meeting_id FROM collection_upload_sessions WHERE session_id=%s",
                (session_id,),
            )
            session = cur.fetchone()
            if session is None:
                raise ValueError(f"Upload session not found: {session_id}")

            job_id = f"CJOB-{uuid.uuid4().hex[:12]}"
            cur.execute(
                f"""
                INSERT INTO collection_analysis_jobs
                    (job_id, session_id, asset_id, project_id, meeting_id,
                     transcript_text, language, status, priority, max_attempts)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING {_JOB_COLS}
                """,
                (job_id, session_id, asset_id,
                 session["project_id"], session["meeting_id"],
                 transcript_text, language,
                 AnalysisJobStatus.QUEUED.value, priority,
                 settings.max_job_attempts),
            )
            job = dict(cur.fetchone())
            _log_event(cur, job_id, None, "job_created", None,
                       AnalysisJobStatus.QUEUED.value)
    return job


def get_analysis_job(job_id: str) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"SELECT {_JOB_COLS} FROM collection_analysis_jobs WHERE job_id=%s",
                (job_id,),
            )
            return cur.fetchone()


def list_analysis_jobs(status: str | None = None,
                        meeting_id: str | None = None) -> list[dict]:
    query = f"SELECT {_JOB_COLS} FROM collection_analysis_jobs"
    filters, params = [], []
    if status:
        filters.append("status = %s"); params.append(status)
    if meeting_id:
        filters.append("meeting_id = %s"); params.append(meeting_id)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY created_at DESC"
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(query, tuple(params))
            return cur.fetchall()


# ────────────────────────────────────────────────────────────────────────────
# 내부 워커 전용 (analysis_worker.py 에서만 호출)
# ────────────────────────────────────────────────────────────────────────────

def worker_heartbeat(worker_id: str, worker_name: str,
                      model_name: str, port: int) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO collection_workers
                    (worker_id, worker_name, status, model_name, host_info)
                VALUES (%s,%s,%s,%s,%s)
                ON CONFLICT (worker_id) DO UPDATE SET
                    worker_name = EXCLUDED.worker_name,
                    status = EXCLUDED.status,
                    model_name = EXCLUDED.model_name,
                    host_info = EXCLUDED.host_info,
                    last_heartbeat_at = now()
                """,
                (worker_id, worker_name, "active", model_name,
                 Jsonb({"runtime": "integrated", "port": port})),
            )


def claim_job(worker_id: str, lease_seconds: int) -> dict | None:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT job_id, status
                FROM collection_analysis_jobs
                WHERE status IN (%s, %s) AND attempt_count < max_attempts
                ORDER BY priority ASC, created_at ASC
                LIMIT 1 FOR UPDATE SKIP LOCKED
                """,
                (AnalysisJobStatus.QUEUED.value, AnalysisJobStatus.RETRY_WAIT.value),
            )
            candidate = cur.fetchone()
            if candidate is None:
                return None
            cur.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status=%s, claimed_by=%s,
                    attempt_count = attempt_count + 1,
                    lease_expires_at = now() + (%s || ' seconds')::interval,
                    updated_at = now()
                WHERE job_id=%s
                RETURNING {_JOB_COLS}
                """,
                (AnalysisJobStatus.CLAIMED.value, worker_id,
                 lease_seconds, candidate["job_id"]),
            )
            job = dict(cur.fetchone())
            _log_event(cur, job["job_id"], worker_id, "job_claimed",
                       candidate["status"], AnalysisJobStatus.CLAIMED.value,
                       {"lease_seconds": lease_seconds})
    return job


def start_job(job_id: str, worker_id: str, before_status: str) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE collection_analysis_jobs
                SET status=%s, claimed_by=%s, updated_at=now()
                WHERE job_id=%s
                """,
                (AnalysisJobStatus.RUNNING.value, worker_id, job_id),
            )
            _log_event(cur, job_id, worker_id, "job_started",
                       before_status, AnalysisJobStatus.RUNNING.value)


def complete_job(job_id: str, worker_id: str,
                  model_name: str, result: dict) -> dict:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT status FROM collection_analysis_jobs WHERE job_id=%s FOR UPDATE",
                (job_id,),
            )
            row = cur.fetchone()
            before = row["status"] if row else AnalysisJobStatus.RUNNING.value
            cur.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status=%s, claimed_by=%s,
                    model_name=%s, result_json=%s,
                    platform_callback_status=%s,
                    platform_callback_attempt_count=0,
                    platform_callback_max_attempts=%s,
                    platform_callback_next_attempt_at=now(),
                    platform_callback_last_attempt_at=NULL,
                    platform_callback_completed_at=NULL,
                    platform_callback_last_error=NULL,
                    updated_at=now(), completed_at=now()
                WHERE job_id=%s
                RETURNING {_JOB_COLS}
                """,
                (AnalysisJobStatus.COMPLETED.value, worker_id,
                 model_name, Jsonb(result),
                 PlatformCallbackStatus.PENDING.value,
                 settings.platform_callback_max_attempts,
                 job_id),
            )
            job = dict(cur.fetchone())
            _log_event(cur, job_id, worker_id, "job_completed",
                       before, AnalysisJobStatus.COMPLETED.value,
                       {"model_name": model_name})
    return job


def fail_job(job_id: str, worker_id: str,
              before_status: str, error_message: str) -> dict:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT attempt_count, max_attempts FROM collection_analysis_jobs WHERE job_id=%s",
                (job_id,),
            )
            row = cur.fetchone()
            attempts = row["attempt_count"] if row else 1
            max_att = row["max_attempts"] if row else settings.max_job_attempts
            next_status = (AnalysisJobStatus.RETRY_WAIT.value
                           if attempts < max_att
                           else AnalysisJobStatus.FAILED.value)
            cur.execute(
                f"""
                UPDATE collection_analysis_jobs
                SET status=%s, claimed_by=NULL, lease_expires_at=NULL,
                    last_error=%s, updated_at=now()
                WHERE job_id=%s
                RETURNING {_JOB_COLS}
                """,
                (next_status, error_message, job_id),
            )
            job = dict(cur.fetchone())
            _log_event(cur, job_id, worker_id, "job_failed",
                       before_status, next_status,
                       {"error_message": error_message})
    return job


def requeue_expired_jobs() -> dict:
    with get_connection() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
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
            expired = cur.fetchall()
            for job in expired:
                cur.execute(
                    """
                    UPDATE collection_analysis_jobs
                    SET status=%s, claimed_by=NULL, lease_expires_at=NULL, updated_at=now()
                    WHERE job_id=%s
                    """,
                    (AnalysisJobStatus.RETRY_WAIT.value, job["job_id"]),
                )
                _log_event(cur, job["job_id"], job["claimed_by"],
                           "lease_expired", job["status"],
                           AnalysisJobStatus.RETRY_WAIT.value)
    return {"requeued": len(expired)}

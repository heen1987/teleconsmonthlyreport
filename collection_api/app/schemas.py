from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class HealthOut(BaseModel):
    status: str
    app: str


class UploadSessionCreate(BaseModel):
    project_id: str = Field(min_length=1)
    meeting_id: str = Field(min_length=1)
    requested_by: Optional[str] = None
    file_name: Optional[str] = None
    content_type: Optional[str] = None
    expected_size_bytes: Optional[int] = Field(default=None, gt=0)
    checksum_sha256: Optional[str] = None
    expires_at: Optional[datetime] = None


class UploadSessionOut(BaseModel):
    session_id: str
    project_id: str
    meeting_id: str
    status: str
    upload_token: Optional[str] = None
    expires_at: Optional[datetime] = None


class AudioAssetCreate(BaseModel):
    session_id: str = Field(min_length=1)
    storage_uri: Optional[str] = None
    file_name: Optional[str] = None
    content_type: Optional[str] = None
    size_bytes: Optional[int] = Field(default=None, gt=0)
    checksum_sha256: Optional[str] = None
    duration_seconds: Optional[float] = Field(default=None, ge=0)


class AudioAssetOut(BaseModel):
    asset_id: str
    session_id: str
    project_id: str
    meeting_id: str
    status: str
    storage_uri: Optional[str] = None
    file_name: Optional[str] = None
    content_type: Optional[str] = None
    size_bytes: Optional[int] = None
    checksum_sha256: Optional[str] = None
    duration_seconds: Optional[float] = None


class AnalysisJobCreate(BaseModel):
    session_id: str = Field(min_length=1)
    asset_id: Optional[str] = None
    priority: int = 100
    transcript_text: Optional[str] = None
    language: str = "ko"


class AnalysisJobOut(BaseModel):
    job_id: str
    session_id: Optional[str] = None
    asset_id: Optional[str] = None
    project_id: str
    meeting_id: str
    transcript_text: Optional[str] = None
    language: str = "ko"
    status: str
    claimed_by: Optional[str] = None
    lease_expires_at: Optional[datetime] = None
    model_name: Optional[str] = None
    result_json: Optional[dict[str, Any]] = None
    attempt_count: int
    max_attempts: int
    platform_callback_status: Optional[str] = None
    platform_callback_attempt_count: Optional[int] = None
    platform_callback_max_attempts: Optional[int] = None
    platform_callback_next_attempt_at: Optional[datetime] = None
    platform_callback_last_attempt_at: Optional[datetime] = None
    platform_callback_completed_at: Optional[datetime] = None
    platform_callback_last_error: Optional[str] = None


class WorkerHeartbeat(BaseModel):
    worker_id: str = Field(min_length=1)
    worker_name: Optional[str] = None
    model_name: Optional[str] = None
    status: str = "active"
    current_job_id: Optional[str] = None
    host_info: dict[str, Any] = Field(default_factory=dict)


class ClaimJobRequest(BaseModel):
    worker_id: str = Field(min_length=1)
    lease_seconds: Optional[int] = Field(default=None, gt=0)


class JobStatusUpdate(BaseModel):
    worker_id: str = Field(min_length=1)
    error_message: Optional[str] = None
    payload: dict[str, Any] = Field(default_factory=dict)

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────
# Health
# ──────────────────────────────────────────────

class AnalysisHealth(BaseModel):
    status: Literal["ok"]
    app: str
    model: str


# ──────────────────────────────────────────────
# LLM / STT 직접 호출 스키마
# ──────────────────────────────────────────────

class MeetingAnalysisRequest(BaseModel):
    job_id: str = Field(min_length=1)
    project_id: str = Field(min_length=1)
    meeting_id: str = Field(min_length=1)
    transcript: str = Field(min_length=1)
    language: str = "ko"


class EvidenceRef(BaseModel):
    segment_id: Optional[str] = None
    speaker: Optional[str] = None
    start_ms: Optional[int] = Field(default=None, ge=0)
    end_ms: Optional[int] = Field(default=None, ge=0)
    quote: Optional[str] = None


class TranscriptSegment(BaseModel):
    segment_id: str = Field(min_length=1)
    speaker: Optional[str] = None
    start_ms: Optional[int] = Field(default=None, ge=0)
    end_ms: Optional[int] = Field(default=None, ge=0)
    text: str = Field(min_length=1)


class DecisionCandidate(BaseModel):
    content: str
    evidence: Optional[str] = None
    evidence_refs: list[EvidenceRef] = Field(default_factory=list)
    confidence: float = Field(default=0.5, ge=0, le=1)


class ActionItemCandidate(BaseModel):
    title: str
    assignee: Optional[str] = None
    due_date: Optional[date] = None
    target_module: str = "task"
    evidence: Optional[str] = None
    evidence_refs: list[EvidenceRef] = Field(default_factory=list)
    priority: Literal["low", "medium", "high"] = "medium"
    confidence: float = Field(default=0.5, ge=0, le=1)
    task_conversion_policy: Literal["manual_review_required"] = "manual_review_required"
    task_conversion_status: Literal["candidate", "converted", "rejected"] = "candidate"
    task_conversion_reason: Optional[str] = None


class RiskCandidate(BaseModel):
    title: str
    level: Literal["low", "medium", "high"] = "medium"
    evidence: Optional[str] = None
    evidence_refs: list[EvidenceRef] = Field(default_factory=list)
    confidence: float = Field(default=0.5, ge=0, le=1)


class RequiredResourceCandidate(BaseModel):
    name: str = Field(min_length=1)
    resource_type: Literal["human", "equipment", "room", "vehicle", "software", "other"] = "other"
    quantity: Optional[float] = Field(default=None, gt=0)
    needed_from: Optional[date] = None
    needed_to: Optional[date] = None
    reason: Optional[str] = None
    evidence: Optional[str] = None
    evidence_refs: list[EvidenceRef] = Field(default_factory=list)
    confidence: float = Field(default=0.5, ge=0, le=1)


class MeetingAnalysisPayload(BaseModel):
    schema_version: str = "analysis.v1"
    language: str = "ko"
    summary: str
    transcript_segments: list[TranscriptSegment] = Field(default_factory=list)
    decisions: list[DecisionCandidate] = Field(default_factory=list)
    action_items: list[ActionItemCandidate] = Field(default_factory=list)
    risks: list[RiskCandidate] = Field(default_factory=list)
    required_resources: list[RequiredResourceCandidate] = Field(default_factory=list)
    requires_human_approval: bool = True


class MeetingAnalysisResponse(BaseModel):
    job_id: str
    project_id: str
    meeting_id: str
    model_name: str
    status: Literal["draft"]
    result: MeetingAnalysisPayload


class SttRequest(BaseModel):
    job_id: str = Field(min_length=1)
    audio_path: str = Field(min_length=1)
    language: str = "ko"


class SttResponse(BaseModel):
    job_id: str
    status: Literal["completed"]
    transcript: str


# ──────────────────────────────────────────────
# Collection — Upload Session
# ──────────────────────────────────────────────

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
    expires_at: Optional[datetime] = None
    upload_token: Optional[str] = None  # 생성 직후에만 반환


# ──────────────────────────────────────────────
# Collection — Audio Asset
# ──────────────────────────────────────────────

class AudioAssetCreate(BaseModel):
    session_id: str = Field(min_length=1)
    storage_uri: str = Field(min_length=1)
    file_name: Optional[str] = None
    content_type: Optional[str] = None
    size_bytes: Optional[int] = Field(default=None, gt=0)
    checksum_sha256: Optional[str] = None
    duration_seconds: Optional[float] = Field(default=None, gt=0)


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


# ──────────────────────────────────────────────
# Collection — Analysis Job
# ──────────────────────────────────────────────

class AnalysisJobCreate(BaseModel):
    session_id: str = Field(min_length=1)
    asset_id: Optional[str] = None
    transcript_text: Optional[str] = None
    language: str = "ko"
    priority: int = 100


class AnalysisJobOut(BaseModel):
    job_id: str
    session_id: Optional[str] = None
    asset_id: Optional[str] = None
    project_id: str
    meeting_id: str
    status: str
    transcript_text: Optional[str] = None
    language: Optional[str] = None
    claimed_by: Optional[str] = None
    lease_expires_at: Optional[datetime] = None
    model_name: Optional[str] = None
    result_json: Optional[Any] = None
    attempt_count: int = 0
    max_attempts: int = 3
    platform_callback_status: Optional[str] = None
    platform_callback_attempt_count: Optional[int] = None
    platform_callback_max_attempts: Optional[int] = None
    platform_callback_next_attempt_at: Optional[datetime] = None
    platform_callback_last_attempt_at: Optional[datetime] = None
    platform_callback_completed_at: Optional[datetime] = None
    platform_callback_last_error: Optional[str] = None


# ──────────────────────────────────────────────
# Collection — Worker / Job Control
# ──────────────────────────────────────────────

class WorkerHeartbeat(BaseModel):
    worker_id: str = Field(min_length=1)
    worker_name: Optional[str] = None
    status: str = "active"
    current_job_id: Optional[str] = None
    model_name: Optional[str] = None
    host_info: dict = Field(default_factory=dict)


class ClaimJobRequest(BaseModel):
    worker_id: str = Field(min_length=1)
    lease_seconds: Optional[int] = Field(default=None, gt=0)


class JobStatusUpdate(BaseModel):
    worker_id: str = Field(min_length=1)
    payload: dict = Field(default_factory=dict)
    error_message: Optional[str] = None

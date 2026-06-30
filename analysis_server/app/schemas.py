from __future__ import annotations

from datetime import date
from typing import Literal, Optional

from pydantic import BaseModel, Field


class AnalysisHealth(BaseModel):
    status: Literal["ok"]
    app: str
    model: str


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

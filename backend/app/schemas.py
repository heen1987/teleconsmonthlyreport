from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    employee_no: str = Field(min_length=1)
    name: str = Field(min_length=1)
    email: Optional[str] = None
    role: Literal["admin", "pm", "pl", "member", "finance", "resource_manager", "viewer"] = "member"
    initial_password: str = Field(default="1234", min_length=4)


class UserOut(BaseModel):
    user_id: str
    employee_no: str
    name: str
    email: Optional[str] = None
    role: str
    status: str


class UserUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1)
    email: Optional[str] = None
    role: Optional[Literal["admin", "pm", "pl", "member", "finance", "resource_manager", "viewer"]] = None
    status: Optional[Literal["password_change_required", "active", "locked", "disabled"]] = None


class AdminPasswordResetRequest(BaseModel):
    new_password: str = Field(default="1234", min_length=4)
    force_password_change: bool = True


class AdminPasswordResetOut(BaseModel):
    user: UserOut
    password_change_required: bool
    revoked_tokens: int


class LoginRequest(BaseModel):
    employee_no: str = Field(min_length=1)
    password: str = Field(min_length=1)


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserOut
    password_change_required: bool


class PasswordChangeRequest(BaseModel):
    employee_no: str = Field(min_length=1)
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=4)


class PasswordResetRequest(BaseModel):
    employee_no: str = Field(min_length=1)
    email: str = Field(min_length=1)


class PasswordResetRequestOut(BaseModel):
    employee_no: str
    email: str
    expires_at: datetime
    delivery_status: Literal["dev_token_returned", "email_queued"]
    reset_token: Optional[str] = None


class PasswordResetVerifyOut(BaseModel):
    valid: bool
    employee_no: str
    email: Optional[str] = None
    expires_at: datetime


class PasswordResetConfirmRequest(BaseModel):
    token: str = Field(min_length=1)
    new_password: str = Field(min_length=4)


class PasswordResetConfirmOut(BaseModel):
    employee_no: str
    status: str
    revoked_tokens: int


class AndroidUpdateManifestOut(BaseModel):
    enabled: bool
    package_name: str
    latest_version_code: int
    latest_version_name: str
    apk_url: Optional[str] = None
    sha256: Optional[str] = None
    mandatory: bool = False
    release_notes: str = ""


class ProjectCreate(BaseModel):
    project_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    description: Optional[str] = None
    pm_user_id: Optional[str] = None


class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1)
    description: Optional[str] = None
    pm_user_id: Optional[str] = None


class ProjectOut(ProjectCreate):
    status: str


class ProjectMemberAdd(BaseModel):
    user_id: str = Field(min_length=1)
    project_role: str = "member"
    allocation_percent: float = Field(default=100.0, ge=0, le=100)
    planned_mm: float = Field(default=1.0, ge=0)
    staffing_note: Optional[str] = None
    annual_salary_krw: Optional[float] = Field(default=None, ge=0)
    allocated_cost_krw: Optional[float] = Field(default=None, ge=0)


class ProjectMemberOut(BaseModel):
    project_id: str
    user_id: str
    employee_no: str
    name: str
    email: Optional[str] = None
    user_role: Optional[str] = None
    project_role: str
    allocation_percent: float = 100.0
    planned_mm: float = 1.0
    staffing_note: Optional[str] = None
    annual_salary_krw: Optional[float] = None
    allocated_cost_krw: Optional[float] = None


class TaskOut(BaseModel):
    task_id: str
    project_id: str
    source_meeting_id: Optional[str] = None
    source_analysis_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    assignee: Optional[str] = None
    due_date: Optional[date] = None
    priority: str
    status: str
    conversion_status: str


class RiskOut(BaseModel):
    risk_id: str
    project_id: str
    source_meeting_id: Optional[str] = None
    source_analysis_id: Optional[str] = None
    title: str
    level: str
    evidence: Optional[str] = None
    evidence_refs: list[dict[str, Any]] = Field(default_factory=list)
    ai_confidence: Optional[float] = None
    status: str


class DelayedTaskRiskPromotionOut(BaseModel):
    scanned_overdue_tasks: int
    created_risks: list[RiskOut] = Field(default_factory=list)


class CostCandidateRiskPromotionOut(BaseModel):
    scanned_cost_candidates: int
    threshold_amount: float
    currency: str
    created_risks: list[RiskOut] = Field(default_factory=list)


class ResourceConflictRiskPromotionOut(BaseModel):
    scanned_conflicts: int
    created_risks: list[RiskOut] = Field(default_factory=list)


class UnassignedResourceDemandRiskPromotionOut(BaseModel):
    scanned_demands: int
    due_within_days: int
    created_risks: list[RiskOut] = Field(default_factory=list)


class ResourceUsageOverrunRiskPromotionOut(BaseModel):
    scanned_usage_entries: int
    threshold_ratio: float
    created_risks: list[RiskOut] = Field(default_factory=list)


class ResourceDemandOut(BaseModel):
    demand_id: str
    project_id: str
    source_meeting_id: Optional[str] = None
    source_analysis_id: Optional[str] = None
    name: str
    resource_type: str
    quantity: Optional[float] = None
    needed_from: Optional[date] = None
    needed_to: Optional[date] = None
    reason: Optional[str] = None
    demand_status: str


class ProjectKnowledgeItemOut(BaseModel):
    knowledge_id: str
    project_id: str
    source_meeting_id: Optional[str] = None
    source_analysis_id: Optional[str] = None
    item_kind: str
    source_item_index: int = 0
    title: str
    content: str
    evidence_refs: list[dict[str, Any]] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    status: str
    created_at: datetime


class ResourceProfileCreate(BaseModel):
    resource_name: str = Field(min_length=1)
    resource_type: Literal["human", "equipment", "room", "vehicle", "software", "other"] = "other"
    capacity: float = Field(default=1, gt=0)
    unit: str = Field(default="unit", min_length=1)
    location: Optional[str] = None
    owner_user_id: Optional[str] = None
    status: Literal["active", "inactive", "retired"] = "active"


class ResourceProfileOut(BaseModel):
    resource_id: str
    resource_name: str
    resource_type: str
    capacity: float
    unit: str
    location: Optional[str] = None
    owner_user_id: Optional[str] = None
    status: str
    created_by: Optional[str] = None


class ResourceCalendarBlockCreate(BaseModel):
    project_id: Optional[str] = None
    starts_on: date
    ends_on: date
    block_type: Literal["blackout", "maintenance", "holiday", "reservation_hold"] = "blackout"
    reason: Optional[str] = None


class ResourceCalendarBlockOut(BaseModel):
    block_id: str
    resource_id: str
    project_id: Optional[str] = None
    starts_on: date
    ends_on: date
    block_type: str
    reason: Optional[str] = None
    created_by: Optional[str] = None


class ResourceProfileAvailabilityOut(ResourceProfileOut):
    is_available: bool
    blocking_allocation_id: Optional[str] = None
    blocking_calendar_block_id: Optional[str] = None


class ResourceAllocationCreate(BaseModel):
    resource_id: Optional[str] = None
    resource_name: Optional[str] = Field(default=None, min_length=1)
    allocation_type: Literal["assignment", "reservation"] = "assignment"
    assignee_user_id: Optional[str] = None
    quantity: Optional[float] = Field(default=None, gt=0)
    starts_on: Optional[date] = None
    ends_on: Optional[date] = None


class ResourceAllocationStatusUpdate(BaseModel):
    status: Literal["proposed", "confirmed", "released", "cancelled"]


class ResourceAllocationOut(BaseModel):
    allocation_id: str
    demand_id: str
    project_id: str
    resource_id: Optional[str] = None
    resource_name: str
    resource_type: str
    allocation_type: str
    assignee_user_id: Optional[str] = None
    quantity: Optional[float] = None
    starts_on: Optional[date] = None
    ends_on: Optional[date] = None
    status: str
    conflict_reason: Optional[str] = None
    created_by: Optional[str] = None


class ResourceUsageCreate(BaseModel):
    usage_date: date
    quantity: float = Field(gt=0)
    unit: str = Field(default="unit", min_length=1)
    cost_amount: Optional[float] = Field(default=None, ge=0)
    note: Optional[str] = None


class ResourceUsageOut(BaseModel):
    usage_id: str
    allocation_id: str
    project_id: str
    resource_id: Optional[str] = None
    resource_name: str
    resource_type: str
    usage_date: date
    quantity: float
    unit: str
    cost_amount: Optional[float] = None
    usage_status: str
    note: Optional[str] = None
    created_by: Optional[str] = None


class ProjectCostCandidateOut(BaseModel):
    cost_id: str
    project_id: str
    source_type: str
    source_id: str
    cost_type: str
    amount: float
    currency: str
    status: str
    description: Optional[str] = None
    created_by: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    review_note: Optional[str] = None


class ProjectCostCandidateStatusUpdate(BaseModel):
    status: Literal["approved", "rejected"]
    review_note: Optional[str] = None


class ProjectCostHandoffCreate(BaseModel):
    target_system: str = Field(default="external_erp", min_length=1)
    external_reference: Optional[str] = None


class ProjectCostHandoffStatusUpdate(BaseModel):
    status: Literal["accepted", "rejected", "failed"]
    external_reference: Optional[str] = None
    response_payload: dict[str, Any] = Field(default_factory=dict)
    response_note: Optional[str] = None


class ProjectCostHandoffSendDueRequest(BaseModel):
    limit: int = Field(default=10, ge=1, le=100)


class ProjectCostHandoffOut(BaseModel):
    handoff_id: str
    cost_id: str
    project_id: str
    target_system: str
    payload: dict[str, Any]
    status: str
    external_reference: Optional[str] = None
    requested_by: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    response_payload: dict[str, Any] = Field(default_factory=dict)
    response_note: Optional[str] = None
    response_received_by: Optional[str] = None
    delivery_mode: str = "dev_log"
    attempt_count: int = 0
    last_error: Optional[str] = None
    next_retry_at: Optional[datetime] = None
    last_attempted_at: Optional[datetime] = None


class ResourceUsageRecordOut(BaseModel):
    usage: ResourceUsageOut
    cost_candidate: Optional[ProjectCostCandidateOut] = None


class DashboardSummaryOut(BaseModel):
    projects: int = 0
    meetings: int = 0
    pending_reviews: int = 0
    draft_tasks: int = 0
    overdue_tasks: int = 0
    resource_demands: int = 0
    resource_usage_entries: int = 0
    cost_candidates: int = 0
    candidate_risks: int = 0
    unresolved_risks: int = 0
    resource_conflicts: int = 0
    distribution_failures: int = 0
    knowledge_items: int = 0


class ProjectDashboardOut(BaseModel):
    project_id: str
    tasks_total: int
    tasks_draft: int
    tasks_overdue: int = 0
    meetings_total: int
    pending_reviews: int
    resource_demands_candidate: int
    risks_candidate: int
    risks_unresolved: int = 0
    resource_conflicts: int = 0
    distribution_failures: int = 0
    knowledge_items: int = 0


class ProjectDetailOut(ProjectOut):
    members: list[ProjectMemberOut] = Field(default_factory=list)
    tasks: list[TaskOut] = Field(default_factory=list)
    resource_demands: list[ResourceDemandOut] = Field(default_factory=list)
    knowledge_items: list[ProjectKnowledgeItemOut] = Field(default_factory=list)
    dashboard: ProjectDashboardOut


class OperationQueueSectionOut(BaseModel):
    status_counts: dict[str, int] = Field(default_factory=dict)
    retry_due: int = 0
    attention_count: int = 0
    latest_created_at: Optional[datetime] = None
    next_retry_at: Optional[datetime] = None
    last_error: Optional[str] = None


class OperationQueueStatusOut(BaseModel):
    generated_at: datetime
    email_distributions: OperationQueueSectionOut
    erp_handoffs: OperationQueueSectionOut


class MeetingCreate(BaseModel):
    meeting_id: str = Field(min_length=1)
    project_id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    created_by: Optional[str] = None


class MeetingOut(MeetingCreate):
    status: str
    audio_path: Optional[str] = None
    transcript: Optional[str] = None


class MeetingListItemOut(BaseModel):
    meeting_id: str
    project_id: str
    project_name: str
    title: str
    status: str
    created_by: Optional[str] = None
    created_at: datetime
    latest_analysis_id: Optional[str] = None
    latest_analysis_status: Optional[str] = None
    latest_model_name: Optional[str] = None


class MeetingStatusOut(BaseModel):
    screen_id: Literal["A-004", "W-003"] = "A-004"
    meeting_id: str
    project_id: str
    project_name: str
    title: str
    status: str
    progress: int = Field(ge=0, le=100)
    error_code: Optional[str] = None
    latest_analysis_id: Optional[str] = None
    latest_analysis_status: Optional[str] = None
    latest_model_name: Optional[str] = None
    latest_distribution_id: Optional[str] = None
    latest_distribution_status: Optional[str] = None
    created_at: datetime


class MeetingAttendeesReplaceRequest(BaseModel):
    attendee_user_ids: list[str] = Field(default_factory=list)
    actor_user_id: Optional[str] = "system"


class MeetingAttendeeOut(BaseModel):
    meeting_id: str
    user_id: str
    employee_no: str
    name: str
    project_role: str


class MeetingAnalyzeRequest(BaseModel):
    meeting_id: str = Field(min_length=1)
    transcript: str = Field(min_length=1)


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


class MeetingAnalysisResult(BaseModel):
    schema_version: str = "analysis.v1"
    language: str = "ko"
    summary: str
    transcript_segments: list[TranscriptSegment] = Field(default_factory=list)
    decisions: list[DecisionCandidate] = Field(default_factory=list)
    action_items: list[ActionItemCandidate] = Field(default_factory=list)
    risks: list[RiskCandidate] = Field(default_factory=list)
    required_resources: list[RequiredResourceCandidate] = Field(default_factory=list)
    requires_human_approval: bool = True


class MeetingAnalysisOut(BaseModel):
    analysis_id: str
    meeting_id: str
    status: Literal["draft", "review_required", "approved", "rejected", "superseded"]
    model_name: str
    result: MeetingAnalysisResult


class CollectionJobCompleteCallback(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_id: str = Field(min_length=1)
    project_id: str = Field(min_length=1)
    meeting_id: str = Field(min_length=1)
    asset_id: Optional[str] = None
    audio_path: Optional[str] = None
    transcript: Optional[str] = None
    model_name: str = Field(min_length=1)
    result: MeetingAnalysisResult


class CollectionJobCompleteOut(BaseModel):
    job_id: str
    meeting_id: str
    analysis_id: str
    status: Literal["draft", "review_required", "approved", "rejected", "superseded"]
    created: bool


class ReviewCounts(BaseModel):
    transcript_segments: int = 0
    decisions: int = 0
    action_items: int = 0
    risks: int = 0
    required_resources: int = 0


class ReviewCapabilities(BaseModel):
    can_edit: bool
    can_approve: bool
    can_reject: bool
    can_distribute: bool


class MeetingReviewPackage(BaseModel):
    screen_id: Literal["W-004", "W-005", "W-006"] = "W-004"
    meeting: MeetingOut
    analysis_id: str
    analysis_status: Literal["draft", "review_required", "approved", "rejected", "superseded"]
    model_name: str
    result: MeetingAnalysisResult
    counts: ReviewCounts
    capabilities: ReviewCapabilities
    warnings: list[str] = Field(default_factory=list)


class MeetingAnalysisReviewEditRequest(BaseModel):
    result: MeetingAnalysisResult
    actor_user_id: Optional[str] = "system"
    edit_reason: Optional[str] = None


class EmailRecipient(BaseModel):
    email: str = Field(min_length=1)
    name: Optional[str] = None
    role: Optional[str] = None


class EmailDistributionPreviewOut(BaseModel):
    screen_id: Literal["W-006"] = "W-006"
    meeting: MeetingOut
    analysis_id: str
    subject: str
    body: str
    recipients: list[EmailRecipient] = Field(default_factory=list)
    can_distribute: bool
    delivery_mode: Literal["dev_log", "smtp"] = "dev_log"


class EmailDistributionRequest(BaseModel):
    subject: Optional[str] = Field(default=None, min_length=1)
    body: Optional[str] = Field(default=None, min_length=1)
    recipients: Optional[list[EmailRecipient]] = None


class EmailRetryDueRequest(BaseModel):
    limit: int = Field(default=10, ge=1, le=100)


class EmailDeliveryAttemptOut(BaseModel):
    attempt_id: str
    recipient_email: str
    recipient_name: Optional[str] = None
    status: str
    attempt_no: int = 1
    provider_message_id: Optional[str] = None
    error_message: Optional[str] = None
    attempted_at: datetime


class EmailDistributionOut(BaseModel):
    distribution_id: str
    meeting_id: str
    analysis_id: str
    subject: str
    body: str
    recipients: list[EmailRecipient] = Field(default_factory=list)
    status: str
    delivery_mode: str
    requested_by: Optional[str] = None
    attempt_count: int = 0
    last_error: Optional[str] = None
    next_retry_at: Optional[datetime] = None
    created_at: datetime
    sent_at: Optional[datetime] = None
    attempts: list[EmailDeliveryAttemptOut] = Field(default_factory=list)


class AnalysisServerHealthOut(BaseModel):
    reachable: bool
    analysis_server_url: str
    status: Optional[str] = None
    app: Optional[str] = None
    model: Optional[str] = None
    error: Optional[str] = None

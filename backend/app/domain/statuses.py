from enum import StrEnum


class MeetingStatus(StrEnum):
    CREATED = "created"
    UPLOAD_REQUESTED = "upload_requested"
    UPLOADED = "uploaded"
    ANALYSIS_QUEUED = "analysis_queued"
    ANALYZING = "analyzing"
    REVIEW_REQUIRED = "review_required"
    APPROVED = "approved"
    DISTRIBUTED = "distributed"
    UPLOAD_FAILED = "upload_failed"
    ANALYSIS_FAILED = "analysis_failed"
    REVIEW_REJECTED = "review_rejected"
    DISTRIBUTION_FAILED = "distribution_failed"


class AnalysisJobStatus(StrEnum):
    QUEUED = "queued"
    CLAIMED = "claimed"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRY_WAIT = "retry_wait"
    CANCELLED = "cancelled"


class MinutesStatus(StrEnum):
    DRAFT = "draft"
    REVIEW_REQUIRED = "review_required"
    APPROVED = "approved"
    REJECTED = "rejected"
    SUPERSEDED = "superseded"


class DistributionStatus(StrEnum):
    READY = "ready"
    QUEUED = "queued"
    SENDING = "sending"
    SENT = "sent"
    PARTIAL_FAILED = "partial_failed"
    FAILED = "failed"
    RETRY_WAIT = "retry_wait"


class AccountStatus(StrEnum):
    PASSWORD_CHANGE_REQUIRED = "password_change_required"
    ACTIVE = "active"
    LOCKED = "locked"
    DISABLED = "disabled"

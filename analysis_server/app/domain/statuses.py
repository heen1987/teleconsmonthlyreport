from enum import StrEnum


class UploadSessionStatus(StrEnum):
    CREATED = "created"
    UPLOADING = "uploading"
    STORED = "stored"
    VALIDATING = "validating"
    READY = "ready"
    FAILED = "failed"
    EXPIRED = "expired"


class AudioAssetStatus(StrEnum):
    STORED = "stored"
    VALIDATING = "validating"
    VALIDATED = "validated"
    INVALID = "invalid"


class AnalysisJobStatus(StrEnum):
    QUEUED = "queued"
    CLAIMED = "claimed"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRY_WAIT = "retry_wait"
    CANCELLED = "cancelled"


class PlatformCallbackStatus(StrEnum):
    PENDING = "pending"
    SENDING = "sending"
    SUCCEEDED = "succeeded"
    RETRY_WAIT = "retry_wait"
    FAILED = "failed"
    DISABLED = "disabled"


class WorkerStatus(StrEnum):
    ACTIVE = "active"
    IDLE = "idle"
    BUSY = "busy"
    OFFLINE = "offline"

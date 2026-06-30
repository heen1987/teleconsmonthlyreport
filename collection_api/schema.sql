CREATE TABLE IF NOT EXISTS collection_upload_sessions (
    session_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    meeting_id TEXT NOT NULL,
    requested_by TEXT,
    file_name TEXT,
    content_type TEXT,
    expected_size_bytes BIGINT,
    checksum_sha256 TEXT,
    upload_token_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'created',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS collection_audio_assets (
    asset_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES collection_upload_sessions(session_id),
    project_id TEXT NOT NULL,
    meeting_id TEXT NOT NULL,
    storage_uri TEXT,
    file_name TEXT,
    content_type TEXT,
    size_bytes BIGINT,
    checksum_sha256 TEXT,
    duration_seconds NUMERIC(12,3),
    status TEXT NOT NULL DEFAULT 'stored',
    validation_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS collection_analysis_jobs (
    job_id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES collection_upload_sessions(session_id),
    asset_id TEXT REFERENCES collection_audio_assets(asset_id),
    project_id TEXT NOT NULL,
    meeting_id TEXT NOT NULL,
    transcript_text TEXT,
    language TEXT NOT NULL DEFAULT 'ko',
    status TEXT NOT NULL DEFAULT 'queued',
    priority INTEGER NOT NULL DEFAULT 100,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    claimed_by TEXT,
    lease_expires_at TIMESTAMPTZ,
    model_name TEXT,
    result_json JSONB,
    last_error TEXT,
    platform_callback_status TEXT NOT NULL DEFAULT 'pending',
    platform_callback_attempt_count INTEGER NOT NULL DEFAULT 0,
    platform_callback_max_attempts INTEGER NOT NULL DEFAULT 5,
    platform_callback_next_attempt_at TIMESTAMPTZ,
    platform_callback_last_attempt_at TIMESTAMPTZ,
    platform_callback_completed_at TIMESTAMPTZ,
    platform_callback_last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS transcript_text TEXT;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'ko';
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS model_name TEXT;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS result_json JSONB;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_attempt_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_max_attempts INTEGER NOT NULL DEFAULT 5;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_next_attempt_at TIMESTAMPTZ;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_last_attempt_at TIMESTAMPTZ;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_completed_at TIMESTAMPTZ;
ALTER TABLE collection_analysis_jobs ADD COLUMN IF NOT EXISTS platform_callback_last_error TEXT;

CREATE TABLE IF NOT EXISTS collection_workers (
    worker_id TEXT PRIMARY KEY,
    worker_name TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    current_job_id TEXT,
    last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    model_name TEXT,
    host_info JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS collection_job_event_logs (
    event_id BIGSERIAL PRIMARY KEY,
    job_id TEXT NOT NULL,
    worker_id TEXT,
    event_type TEXT NOT NULL,
    before_status TEXT,
    after_status TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_collection_jobs_claimable
ON collection_analysis_jobs (status, priority, created_at);

CREATE INDEX IF NOT EXISTS idx_collection_jobs_meeting
ON collection_analysis_jobs (meeting_id);

CREATE INDEX IF NOT EXISTS idx_collection_jobs_callback_retry
ON collection_analysis_jobs (platform_callback_status, platform_callback_next_attempt_at)
WHERE platform_callback_status IN ('pending', 'retry_wait');

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    employee_no TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'member',
    password_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'password_change_required',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS access_tokens (
    token_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_access_tokens_user
ON access_tokens (user_id);

CREATE INDEX IF NOT EXISTS idx_access_tokens_active
ON access_tokens (token_hash)
WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS projects (
    project_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    pm_user_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_members (
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    user_id TEXT NOT NULL REFERENCES users(user_id),
    project_role TEXT NOT NULL DEFAULT 'member',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE IF NOT EXISTS meetings (
    meeting_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'created',
    audio_path TEXT,
    transcript TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meeting_attendees (
    meeting_id TEXT NOT NULL REFERENCES meetings(meeting_id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (meeting_id, user_id)
);

CREATE TABLE IF NOT EXISTS analysis_jobs (
    job_id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL REFERENCES meetings(meeting_id),
    status TEXT NOT NULL DEFAULT 'queued',
    analysis_server_url TEXT NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS meeting_analyses (
    analysis_id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL REFERENCES meetings(meeting_id),
    source_collection_job_id TEXT,
    source_asset_id TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    model_name TEXT NOT NULL,
    summary TEXT NOT NULL,
    result_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at TIMESTAMPTZ
);

ALTER TABLE meeting_analyses ADD COLUMN IF NOT EXISTS source_collection_job_id TEXT;
ALTER TABLE meeting_analyses ADD COLUMN IF NOT EXISTS source_asset_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_meeting_analyses_source_collection_job
ON meeting_analyses (source_collection_job_id)
WHERE source_collection_job_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS tasks (
    task_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id),
    source_action_item_index INTEGER,
    title TEXT NOT NULL,
    description TEXT,
    assignee TEXT,
    due_date DATE,
    priority TEXT NOT NULL DEFAULT 'medium',
    ai_confidence NUMERIC(4,3),
    evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    conversion_policy TEXT NOT NULL DEFAULT 'manual_review_required',
    conversion_status TEXT NOT NULL DEFAULT 'draft',
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS source_action_item_index INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'medium';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS ai_confidence NUMERIC(4,3);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS conversion_policy TEXT NOT NULL DEFAULT 'manual_review_required';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS conversion_status TEXT NOT NULL DEFAULT 'draft';

CREATE TABLE IF NOT EXISTS schedules (
    schedule_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    title TEXT NOT NULL,
    start_date DATE,
    end_date DATE,
    milestone BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'planned',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_decisions (
    decision_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resource_demands (
    demand_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id),
    source_required_resource_index INTEGER,
    name TEXT NOT NULL,
    resource_type TEXT NOT NULL DEFAULT 'other',
    quantity NUMERIC(12,3),
    needed_from DATE,
    needed_to DATE,
    reason TEXT,
    evidence TEXT,
    evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    ai_confidence NUMERIC(4,3),
    demand_status TEXT NOT NULL DEFAULT 'candidate',
    conversion_policy TEXT NOT NULL DEFAULT 'manual_review_required',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS risks (
    risk_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id),
    title TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'medium',
    evidence TEXT,
    evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    ai_confidence NUMERIC(4,3),
    status TEXT NOT NULL DEFAULT 'candidate',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    actor_user_id TEXT,
    action_type TEXT NOT NULL,
    target_table TEXT NOT NULL,
    target_id TEXT NOT NULL,
    before_value JSONB,
    after_value JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

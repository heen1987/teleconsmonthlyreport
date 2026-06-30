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

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    reset_token_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    requested_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    last_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_status
ON password_reset_tokens (user_id, status, expires_at);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_pending_hash
ON password_reset_tokens (token_hash)
WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS projects (
    project_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    pm_user_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_members (
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    user_id TEXT NOT NULL REFERENCES users(user_id),
    project_role TEXT NOT NULL DEFAULT 'member',
    allocation_percent NUMERIC(5,2) NOT NULL DEFAULT 100.00,
    planned_mm NUMERIC(6,2) NOT NULL DEFAULT 1.00,
    staffing_note TEXT,
    annual_salary_krw NUMERIC(14,0),
    allocated_cost_krw NUMERIC(14,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_project_members_user_allocation
ON project_members (user_id, project_id);

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

CREATE TABLE IF NOT EXISTS project_knowledge_items (
    knowledge_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id),
    item_kind TEXT NOT NULL,
    source_item_index INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_analysis_id, item_kind, source_item_index)
);

CREATE INDEX IF NOT EXISTS idx_project_knowledge_items_project_kind
ON project_knowledge_items (project_id, item_kind, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_knowledge_items_source_analysis
ON project_knowledge_items (source_analysis_id);

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

CREATE TABLE IF NOT EXISTS resource_profiles (
    resource_id TEXT PRIMARY KEY,
    resource_type TEXT NOT NULL DEFAULT 'other',
    resource_name TEXT NOT NULL,
    capacity NUMERIC(12,3) NOT NULL DEFAULT 1,
    unit TEXT NOT NULL DEFAULT 'unit',
    location TEXT,
    owner_user_id TEXT REFERENCES users(user_id),
    status TEXT NOT NULL DEFAULT 'active',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resource_profiles_type_status
ON resource_profiles (resource_type, status);

CREATE INDEX IF NOT EXISTS idx_resource_profiles_name
ON resource_profiles (resource_name);

CREATE TABLE IF NOT EXISTS resource_calendar_blocks (
    block_id TEXT PRIMARY KEY,
    resource_id TEXT NOT NULL REFERENCES resource_profiles(resource_id) ON DELETE CASCADE,
    project_id TEXT REFERENCES projects(project_id),
    starts_on DATE NOT NULL,
    ends_on DATE NOT NULL,
    block_type TEXT NOT NULL DEFAULT 'blackout',
    reason TEXT,
    created_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (starts_on <= ends_on)
);

CREATE INDEX IF NOT EXISTS idx_resource_calendar_blocks_resource_window
ON resource_calendar_blocks (resource_id, starts_on, ends_on);

CREATE INDEX IF NOT EXISTS idx_resource_calendar_blocks_project
ON resource_calendar_blocks (project_id, starts_on DESC);

CREATE TABLE IF NOT EXISTS resource_allocations (
    allocation_id TEXT PRIMARY KEY,
    demand_id TEXT NOT NULL REFERENCES resource_demands(demand_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    resource_id TEXT REFERENCES resource_profiles(resource_id),
    resource_name TEXT NOT NULL,
    resource_type TEXT NOT NULL DEFAULT 'other',
    allocation_type TEXT NOT NULL DEFAULT 'assignment',
    assignee_user_id TEXT REFERENCES users(user_id),
    quantity NUMERIC(12,3),
    starts_on DATE,
    ends_on DATE,
    status TEXT NOT NULL DEFAULT 'proposed',
    conflict_reason TEXT,
    created_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resource_allocations_project
ON resource_allocations (project_id, starts_on, ends_on);

CREATE INDEX IF NOT EXISTS idx_resource_allocations_demand
ON resource_allocations (demand_id);

CREATE INDEX IF NOT EXISTS idx_resource_allocations_resource_window
ON resource_allocations (resource_name, starts_on, ends_on)
WHERE status IN ('proposed', 'confirmed');

CREATE INDEX IF NOT EXISTS idx_resource_allocations_resource_id_window
ON resource_allocations (resource_id, starts_on, ends_on)
WHERE status IN ('proposed', 'confirmed') AND resource_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS resource_usage_entries (
    usage_id TEXT PRIMARY KEY,
    allocation_id TEXT NOT NULL REFERENCES resource_allocations(allocation_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    resource_id TEXT REFERENCES resource_profiles(resource_id),
    resource_name TEXT NOT NULL,
    resource_type TEXT NOT NULL DEFAULT 'other',
    usage_date DATE NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit TEXT NOT NULL DEFAULT 'unit',
    cost_amount NUMERIC(14,2),
    usage_status TEXT NOT NULL DEFAULT 'recorded',
    note TEXT,
    created_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resource_usage_entries_project_date
ON resource_usage_entries (project_id, usage_date DESC);

CREATE INDEX IF NOT EXISTS idx_resource_usage_entries_allocation
ON resource_usage_entries (allocation_id, usage_date DESC);

CREATE TABLE IF NOT EXISTS project_cost_candidates (
    cost_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_type TEXT NOT NULL DEFAULT 'resource_usage',
    source_id TEXT NOT NULL,
    cost_type TEXT NOT NULL DEFAULT 'resource_usage',
    amount NUMERIC(14,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'KRW',
    status TEXT NOT NULL DEFAULT 'candidate',
    description TEXT,
    created_by TEXT REFERENCES users(user_id),
    reviewed_by TEXT REFERENCES users(user_id),
    reviewed_at TIMESTAMPTZ,
    review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_project_cost_candidates_source
ON project_cost_candidates (source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_project_cost_candidates_project_status
ON project_cost_candidates (project_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_cost_candidates_reviewed_by
ON project_cost_candidates (reviewed_by, reviewed_at DESC);

CREATE TABLE IF NOT EXISTS project_cost_handoffs (
    handoff_id TEXT PRIMARY KEY,
    cost_id TEXT NOT NULL REFERENCES project_cost_candidates(cost_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    target_system TEXT NOT NULL DEFAULT 'external_erp',
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    external_reference TEXT,
    requested_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_note TEXT,
    response_received_by TEXT REFERENCES users(user_id),
    delivery_mode TEXT NOT NULL DEFAULT 'dev_log',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    next_retry_at TIMESTAMPTZ,
    last_attempted_at TIMESTAMPTZ,
    UNIQUE (cost_id, target_system)
);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_project_status
ON project_cost_handoffs (project_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_target_status
ON project_cost_handoffs (target_system, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_completed_at
ON project_cost_handoffs (completed_at DESC)
WHERE completed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_send_due
ON project_cost_handoffs (next_retry_at, created_at)
WHERE status IN ('retry_wait');

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_queued
ON project_cost_handoffs (created_at)
WHERE status = 'queued';

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

CREATE TABLE IF NOT EXISTS email_distributions (
    distribution_id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL REFERENCES meetings(meeting_id),
    analysis_id TEXT NOT NULL REFERENCES meeting_analyses(analysis_id),
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    recipients JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'sent',
    delivery_mode TEXT NOT NULL DEFAULT 'dev_log',
    requested_by TEXT REFERENCES users(user_id),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    next_retry_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_email_distributions_meeting
ON email_distributions (meeting_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_distributions_analysis_active
ON email_distributions (analysis_id)
WHERE status IN ('queued', 'sending', 'sent');

CREATE TABLE IF NOT EXISTS email_delivery_attempts (
    attempt_id TEXT PRIMARY KEY,
    distribution_id TEXT NOT NULL REFERENCES email_distributions(distribution_id) ON DELETE CASCADE,
    recipient_email TEXT NOT NULL,
    recipient_name TEXT,
    status TEXT NOT NULL DEFAULT 'sent',
    attempt_no INTEGER NOT NULL DEFAULT 1,
    provider_message_id TEXT,
    error_message TEXT,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_delivery_attempts_distribution
ON email_delivery_attempts (distribution_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_email_distributions_retry_due
ON email_distributions (next_retry_at, created_at)
WHERE status IN ('retry_wait', 'partial_failed', 'failed');

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

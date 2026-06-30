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
    UNIQUE (cost_id, target_system)
);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_project_status
ON project_cost_handoffs (project_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_target_status
ON project_cost_handoffs (target_system, status, created_at DESC);

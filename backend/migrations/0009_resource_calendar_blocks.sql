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

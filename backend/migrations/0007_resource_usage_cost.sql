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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_project_cost_candidates_source
ON project_cost_candidates (source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_project_cost_candidates_project_status
ON project_cost_candidates (project_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS resource_allocations (
    allocation_id TEXT PRIMARY KEY,
    demand_id TEXT NOT NULL REFERENCES resource_demands(demand_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
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

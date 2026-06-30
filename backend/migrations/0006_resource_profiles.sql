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

ALTER TABLE resource_allocations
ADD COLUMN IF NOT EXISTS resource_id TEXT REFERENCES resource_profiles(resource_id);

CREATE INDEX IF NOT EXISTS idx_resource_allocations_resource_id_window
ON resource_allocations (resource_id, starts_on, ends_on)
WHERE status IN ('proposed', 'confirmed') AND resource_id IS NOT NULL;

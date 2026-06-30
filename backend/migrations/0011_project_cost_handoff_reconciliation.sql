ALTER TABLE project_cost_handoffs
    ADD COLUMN IF NOT EXISTS response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS response_note TEXT,
    ADD COLUMN IF NOT EXISTS response_received_by TEXT REFERENCES users(user_id);

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_completed_at
ON project_cost_handoffs (completed_at DESC)
WHERE completed_at IS NOT NULL;

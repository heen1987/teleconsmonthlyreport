ALTER TABLE project_cost_handoffs
    ADD COLUMN IF NOT EXISTS delivery_mode TEXT NOT NULL DEFAULT 'dev_log',
    ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_error TEXT,
    ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_attempted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_send_due
ON project_cost_handoffs (next_retry_at, created_at)
WHERE status IN ('retry_wait');

CREATE INDEX IF NOT EXISTS idx_project_cost_handoffs_queued
ON project_cost_handoffs (created_at)
WHERE status = 'queued';

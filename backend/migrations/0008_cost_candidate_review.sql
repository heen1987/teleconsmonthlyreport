ALTER TABLE project_cost_candidates
    ADD COLUMN IF NOT EXISTS reviewed_by TEXT REFERENCES users(user_id),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS review_note TEXT;

CREATE INDEX IF NOT EXISTS idx_project_cost_candidates_reviewed_by
ON project_cost_candidates (reviewed_by, reviewed_at DESC);

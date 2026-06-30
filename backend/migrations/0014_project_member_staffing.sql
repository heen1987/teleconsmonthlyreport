ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS allocation_percent NUMERIC(5,2) NOT NULL DEFAULT 100.00;

ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS planned_mm NUMERIC(6,2) NOT NULL DEFAULT 1.00;

ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS staffing_note TEXT;

ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS annual_salary_krw NUMERIC(14,0);

ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS allocated_cost_krw NUMERIC(14,2);

CREATE INDEX IF NOT EXISTS idx_project_members_user_allocation
ON project_members (user_id, project_id);

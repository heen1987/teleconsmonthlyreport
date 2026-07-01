CREATE TABLE IF NOT EXISTS company_profiles (
    company_id TEXT PRIMARY KEY,
    company_name TEXT NOT NULL,
    english_name TEXT,
    industry TEXT,
    founded_on DATE,
    headquarters TEXT,
    ceo TEXT,
    fiscal_year TEXT,
    annual_revenue_krw BIGINT,
    headcount INTEGER,
    project_count INTEGER,
    organization_summary TEXT,
    headcount_summary TEXT,
    note TEXT,
    source_file TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_company_profiles_name
ON company_profiles (company_name);

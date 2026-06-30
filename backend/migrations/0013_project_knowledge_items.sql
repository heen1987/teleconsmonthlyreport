CREATE TABLE IF NOT EXISTS project_knowledge_items (
    knowledge_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(project_id),
    source_meeting_id TEXT REFERENCES meetings(meeting_id),
    source_analysis_id TEXT REFERENCES meeting_analyses(analysis_id),
    item_kind TEXT NOT NULL,
    source_item_index INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    evidence_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_analysis_id, item_kind, source_item_index)
);

CREATE INDEX IF NOT EXISTS idx_project_knowledge_items_project_kind
ON project_knowledge_items (project_id, item_kind, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_knowledge_items_source_analysis
ON project_knowledge_items (source_analysis_id);

CREATE TABLE IF NOT EXISTS email_distributions (
    distribution_id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL REFERENCES meetings(meeting_id),
    analysis_id TEXT NOT NULL REFERENCES meeting_analyses(analysis_id),
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    recipients JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'sent',
    delivery_mode TEXT NOT NULL DEFAULT 'dev_log',
    requested_by TEXT REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_email_distributions_meeting
ON email_distributions (meeting_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_distributions_analysis_active
ON email_distributions (analysis_id)
WHERE status IN ('queued', 'sending', 'sent');

CREATE TABLE IF NOT EXISTS email_delivery_attempts (
    attempt_id TEXT PRIMARY KEY,
    distribution_id TEXT NOT NULL REFERENCES email_distributions(distribution_id) ON DELETE CASCADE,
    recipient_email TEXT NOT NULL,
    recipient_name TEXT,
    status TEXT NOT NULL DEFAULT 'sent',
    provider_message_id TEXT,
    error_message TEXT,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_delivery_attempts_distribution
ON email_delivery_attempts (distribution_id, attempted_at DESC);

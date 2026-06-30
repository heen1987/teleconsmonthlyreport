ALTER TABLE email_distributions
ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE email_distributions
ADD COLUMN IF NOT EXISTS last_error TEXT;

ALTER TABLE email_distributions
ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ;

ALTER TABLE email_delivery_attempts
ADD COLUMN IF NOT EXISTS attempt_no INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_email_distributions_retry_due
ON email_distributions (next_retry_at, created_at)
WHERE status IN ('retry_wait', 'partial_failed', 'failed');

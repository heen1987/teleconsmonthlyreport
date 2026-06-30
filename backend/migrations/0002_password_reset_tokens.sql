CREATE TABLE IF NOT EXISTS password_reset_tokens (
    reset_token_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    requested_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    last_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_status
ON password_reset_tokens (user_id, status, expires_at);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_pending_hash
ON password_reset_tokens (token_hash)
WHERE status = 'pending';

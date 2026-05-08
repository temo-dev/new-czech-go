-- V25 — Sign-in with Apple subject claim on users.
--
-- Adds users.apple_sub so the V25 /v1/auth/apple handler can upsert
-- accounts keyed by Apple's stable subject identifier. The column is
-- nullable because email-only accounts (V17 and earlier) do not have
-- one, and the partial unique index allows multiple NULL rows while
-- preventing two Apple-linked accounts from sharing the same sub.
--
-- Mirrored at runtime by ensureSchema in
-- backend/internal/store/postgres_users.go so containers without a
-- manual goose step still come up with the column.
--
-- Idempotent: re-running this file is a no-op.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS apple_sub TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_apple_sub_uniq
    ON users (apple_sub)
    WHERE apple_sub IS NOT NULL AND deleted_at IS NULL;

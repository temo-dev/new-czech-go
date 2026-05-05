-- V17 Self-Serve Learner — users table.
--
-- Replaces the in-memory `MemoryStore.usersByToken` fixture map with a real
-- learner identity record. Auth tokens, streak history, IAP receipts, and
-- daily usage live in their own tables (added by 023_users.sql siblings in
-- V17-A1.2 and V17-A1.3).
--
-- Idempotent: safe to re-run on existing databases (CREATE IF NOT EXISTS).
--
-- Spec: docs/specs/self-serve-learner-spec.md §3.1
-- Plan: docs/plans/self-serve-learner-plan.md Phase A1

CREATE TABLE IF NOT EXISTS users (
    id                  TEXT        PRIMARY KEY,
    email               TEXT        NOT NULL,
    email_normalized    TEXT        NOT NULL,
    email_verified_at   TIMESTAMPTZ,
    password_hash       TEXT        NOT NULL,
    display_name        TEXT        NOT NULL DEFAULT '',
    avatar_asset_id     TEXT,
    role                TEXT        NOT NULL DEFAULT 'learner',
    pro_tier            TEXT        NOT NULL DEFAULT 'free',
    pro_expires_at      TIMESTAMPTZ,
    onboarding_goal     TEXT,
    onboarding_level    TEXT,
    daily_reminder_at   TEXT,
    push_token          TEXT,
    push_token_platform TEXT,
    timezone            TEXT        NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    grace_attempts_left INTEGER     NOT NULL DEFAULT 3,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

-- Email uniqueness applies only to non-deleted accounts so that a soft-deleted
-- user does not block re-registration with the same email after anonymization.
CREATE UNIQUE INDEX IF NOT EXISTS users_email_normalized_uniq
    ON users (email_normalized)
    WHERE deleted_at IS NULL;

-- Lookup index for admin dashboards filtering by role / status.
CREATE INDEX IF NOT EXISTS users_role_idx
    ON users (role)
    WHERE deleted_at IS NULL;

-- Pro subscription expiry sweep (e.g., daily downgrade cron in V18).
CREATE INDEX IF NOT EXISTS users_pro_expires_at_idx
    ON users (pro_expires_at)
    WHERE pro_tier = 'pro' AND deleted_at IS NULL;

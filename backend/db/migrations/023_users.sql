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

-- ─────────────────────────────────────────────────────────────────────────
-- V17-A1.2 — auth_tokens
--
-- Stores sha256-hashed bearer tokens for sessions, email-verify links, and
-- password-reset links. Raw tokens are never persisted: only the hash. Rows
-- are pruned by sweeping `expires_at` and `revoked_at`; a CASCADE on the
-- user FK keeps the table self-cleaning when accounts are hard-deleted.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS auth_tokens (
    token_hash   TEXT        PRIMARY KEY,
    user_id      TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind         TEXT        NOT NULL,
    expires_at   TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at   TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    user_agent   TEXT,
    ip_address   TEXT
);

-- Active-token lookup by (user, kind) — used by middleware to authenticate
-- bearer tokens and by reset/verify flows that revoke previous siblings.
CREATE INDEX IF NOT EXISTS auth_tokens_user_kind_idx
    ON auth_tokens (user_id, kind)
    WHERE revoked_at IS NULL;

-- Expiry sweep — used by the cleanup job to delete stale tokens.
CREATE INDEX IF NOT EXISTS auth_tokens_expires_at_idx
    ON auth_tokens (expires_at)
    WHERE revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- V17-A1.3 — streak_days
--
-- One row per learner per local-VN day. `completed=true` means the learner
-- finished at least one attempt that day; `grace_used=true` means a Pro
-- learner spent their weekly grace pass to keep the streak alive across an
-- otherwise-empty day. Composite PK makes the daily upsert idempotent.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS streak_days (
    user_id    TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day        DATE        NOT NULL,
    completed  BOOLEAN     NOT NULL DEFAULT FALSE,
    grace_used BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, day)
);

-- Reverse-chronological per-user lookup for streak history calendars.
CREATE INDEX IF NOT EXISTS streak_days_user_day_idx
    ON streak_days (user_id, day DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- V17-A1.3 — pro_purchases
--
-- Apple IAP receipts. Each StoreKit transaction lands here exactly once
-- (apple_transaction_id is globally unique). The webhook handler flips
-- `is_active` when Apple sends RENEWAL / EXPIRED / REFUND notifications.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS pro_purchases (
    id                            TEXT        PRIMARY KEY,
    user_id                       TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apple_transaction_id          TEXT        NOT NULL,
    apple_original_transaction_id TEXT        NOT NULL,
    product_id                    TEXT        NOT NULL,
    purchased_at                  TIMESTAMPTZ NOT NULL,
    expires_at                    TIMESTAMPTZ NOT NULL,
    receipt_payload               JSONB       NOT NULL,
    is_active                     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at                    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Globally unique transaction id prevents double-credit on receipt replay.
CREATE UNIQUE INDEX IF NOT EXISTS pro_purchases_apple_txn_uniq
    ON pro_purchases (apple_transaction_id);

-- Active-subscription lookup per user (renewal sweep, downgrade cron).
CREATE INDEX IF NOT EXISTS pro_purchases_user_active_idx
    ON pro_purchases (user_id)
    WHERE is_active = TRUE;

-- ─────────────────────────────────────────────────────────────────────────
-- V17-A1.3 — daily_usage
--
-- Free-tier rate limit ledger. Composite PK on (user_id, day) keeps the
-- counter idempotent under upsert; daily reset is implicit because each
-- new day creates a new row. Pro learners bypass this table.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS daily_usage (
    user_id          TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day              DATE    NOT NULL,
    attempts_count   INTEGER NOT NULL DEFAULT 0,
    interviews_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);

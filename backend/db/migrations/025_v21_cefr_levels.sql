-- V21 — CEFR level progression (A0 → B1).
--
-- Adds level gating to courses, users and mock_tests, plus a new
-- promotion_attempts ledger. See docs/specs/cefr-level-progression.md for the
-- full design and SPEC.md § V21 for the summary.
--
-- All statements are idempotent (IF NOT EXISTS / re-runnable CHECK adds) so
-- this file is safe to apply against existing databases via goose and is
-- mirrored by ensureSchema runtime DDL in the corresponding postgres_*.go
-- stores.

-- ── courses.level ────────────────────────────────────────────────────────────
-- Existing courses backfill to 'a2' so the current product (A2 sprint) keeps
-- working after the migration. The CHECK constraint ties the column to the
-- four supported levels; CHECKs are dropped/recreated using the standard
-- DO-block guard so the file remains idempotent.
ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS level TEXT NOT NULL DEFAULT 'a2';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'courses_level_check'
    ) THEN
        ALTER TABLE courses
            ADD CONSTRAINT courses_level_check
            CHECK (level IN ('a0','a1','a2','b1'));
    END IF;
END$$;

CREATE INDEX IF NOT EXISTS courses_level_idx ON courses (level);

-- Demo exercise per locked upper-level course (V21 spec § Course endpoint
-- modifications). Nullable; CMS authors pick a single exercise per course.
ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS demo_exercise_id TEXT NOT NULL DEFAULT '';

-- ── users — current_level / unlocked_levels / placement_taken_at ─────────────
-- New users default to 'a0' with only a0 unlocked. Existing users must be
-- backfilled to 'a2' with {a0,a1,a2} unlocked — that backfill happens
-- idempotently inside the user repository read path (V21-B1) so no one-shot
-- data update is required here.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS current_level TEXT NOT NULL DEFAULT 'a0';

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS unlocked_levels TEXT[] NOT NULL DEFAULT ARRAY['a0'];

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS placement_taken_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'users_current_level_check'
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT users_current_level_check
            CHECK (current_level IN ('a0','a1','a2','b1'));
    END IF;
END$$;

-- ── mock_tests — promotion / placement flags + target level ──────────────────
ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS is_promotion BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS is_placement BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS target_level TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'mock_tests_target_level_check'
    ) THEN
        ALTER TABLE mock_tests
            ADD CONSTRAINT mock_tests_target_level_check
            CHECK (target_level IS NULL OR target_level IN ('a0','a1','a2','b1'));
    END IF;
END$$;

-- A promotion mock must declare its target level. Placement mocks do not.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'mock_tests_promotion_target_required'
    ) THEN
        ALTER TABLE mock_tests
            ADD CONSTRAINT mock_tests_promotion_target_required
            CHECK (is_promotion = FALSE OR target_level IS NOT NULL);
    END IF;
END$$;

-- A mock cannot be both placement and promotion.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'mock_tests_promotion_placement_mutex'
    ) THEN
        ALTER TABLE mock_tests
            ADD CONSTRAINT mock_tests_promotion_placement_mutex
            CHECK (NOT (is_promotion AND is_placement));
    END IF;
END$$;

-- ── promotion_attempts ───────────────────────────────────────────────────────
-- Ledger of every promotion attempt. The cooldown lookup in V21-B2 reads the
-- most recent failed row by (user_id, target_level) — backed by the descending
-- composite index below.
--
-- full_session_id references the existing mock_exam_sessions table (the V8+
-- successor to the dropped full_exam_sessions table from V5).
CREATE TABLE IF NOT EXISTS promotion_attempts (
    id              TEXT        PRIMARY KEY,
    user_id         TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mock_test_id    TEXT        NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    source_level    TEXT        NOT NULL,
    target_level    TEXT        NOT NULL,
    full_session_id TEXT        NOT NULL DEFAULT '',
    passed          BOOLEAN     NOT NULL DEFAULT FALSE,
    score_pct       NUMERIC(5,2) NOT NULL DEFAULT 0,
    per_skill_pct   JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS promotion_attempts_user_idx
    ON promotion_attempts (user_id, target_level, created_at DESC);

-- V21.1 review I4 — add a foreign key from promotion_attempts to
-- mock_exam_sessions so a deleted session does not orphan the ledger
-- row. We use ON DELETE SET NULL (rather than CASCADE) because the
-- ledger row is the audit trail — keep it even if the session is
-- pruned.
--
-- The original migration 025 declared full_session_id as plain TEXT
-- with a default of '' to avoid sequencing issues at boot (the
-- promotion_attempts table is created inside postgresUserStore
-- ensureSchema, after mock_exam_sessions has been ensured by the
-- mock_exam store earlier in the bootstrap, but ad-hoc test setups
-- could rebuild in any order). Now that V21 has shipped and the
-- runtime sequence is stable, we tighten the link.
--
-- The column also flips from NOT NULL DEFAULT '' to NULLABLE so the
-- SET NULL action has somewhere to land.

DO $$
BEGIN
    -- 1. Drop the NOT NULL + DEFAULT, allowing the column to take NULL.
    BEGIN
        ALTER TABLE promotion_attempts
            ALTER COLUMN full_session_id DROP NOT NULL;
    EXCEPTION WHEN others THEN NULL;
    END;

    BEGIN
        ALTER TABLE promotion_attempts
            ALTER COLUMN full_session_id DROP DEFAULT;
    EXCEPTION WHEN others THEN NULL;
    END;

    -- 2. Convert sentinel '' rows to NULL so they no longer pretend to
    --    reference a nonexistent session id.
    UPDATE promotion_attempts SET full_session_id = NULL WHERE full_session_id = '';

    -- 3. Add the FK if not already present. ON DELETE SET NULL keeps
    --    the ledger row even if the session is pruned (audit trail).
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'promotion_attempts_full_session_fk'
    ) THEN
        ALTER TABLE promotion_attempts
            ADD CONSTRAINT promotion_attempts_full_session_fk
            FOREIGN KEY (full_session_id) REFERENCES mock_exam_sessions(id) ON DELETE SET NULL;
    END IF;
END$$;

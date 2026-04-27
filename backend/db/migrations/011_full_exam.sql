-- V5: Full exam session tracking (písemná + ústní).

-- Extend mock_tests with session_type.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mock_tests' AND column_name = 'session_type'
  ) THEN
    ALTER TABLE mock_tests ADD COLUMN session_type TEXT NOT NULL DEFAULT 'speaking';
  END IF;
END $$;

-- Full exam sessions: link písemná score + ústní mock exam session.
CREATE TABLE IF NOT EXISTS full_exam_sessions (
    id                        TEXT        PRIMARY KEY,
    learner_id                TEXT        NOT NULL,
    mock_test_id              TEXT,
    pisemna_score             INT         NOT NULL DEFAULT 0,
    ustni_score               INT         NOT NULL DEFAULT 0,
    pisemna_passed            BOOL        NOT NULL DEFAULT FALSE,
    ustni_passed              BOOL        NOT NULL DEFAULT FALSE,
    overall_passed            BOOL        NOT NULL DEFAULT FALSE,
    status                    TEXT        NOT NULL DEFAULT 'in_progress',
    ustni_mock_exam_session_id TEXT,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_full_exam_sessions_learner ON full_exam_sessions(learner_id);

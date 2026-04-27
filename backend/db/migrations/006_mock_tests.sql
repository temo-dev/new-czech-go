-- Mock test templates (admin-defined exam blueprints)
CREATE TABLE IF NOT EXISTS mock_tests (
    id                          TEXT        PRIMARY KEY,
    title                       TEXT        NOT NULL,
    description                 TEXT        NOT NULL DEFAULT '',
    estimated_duration_minutes  INTEGER     NOT NULL DEFAULT 15,
    status                      TEXT        NOT NULL DEFAULT 'draft',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mock_test_sections (
    mock_test_id  TEXT    NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    sequence_no   INTEGER NOT NULL,
    exercise_id   TEXT    NOT NULL,
    exercise_type TEXT    NOT NULL,
    max_points    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (mock_test_id, sequence_no)
);

-- Extend exam sessions with scoring fields
ALTER TABLE mock_exam_sessions
    ADD COLUMN IF NOT EXISTS mock_test_id   TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS overall_score  INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS passed         BOOLEAN NOT NULL DEFAULT false;

-- Extend exam sections with per-section scoring
ALTER TABLE mock_exam_sections
    ADD COLUMN IF NOT EXISTS section_score  INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS max_points     INTEGER NOT NULL DEFAULT 0;

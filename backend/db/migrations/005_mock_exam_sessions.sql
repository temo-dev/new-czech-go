-- Mock exam session persistence
-- Sessions are associated with a learner and hold overall readiness after completion.
-- Sections track which exercise was used for each Uloha task and which attempt was submitted.

CREATE TABLE IF NOT EXISTS mock_exam_sessions (
    id                      TEXT        PRIMARY KEY,
    learner_id              TEXT        NOT NULL,
    status                  TEXT        NOT NULL DEFAULT 'in_progress',
    overall_readiness_level TEXT        NOT NULL DEFAULT '',
    overall_summary         TEXT        NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mock_exam_sections (
    session_id    TEXT    NOT NULL REFERENCES mock_exam_sessions(id) ON DELETE CASCADE,
    sequence_no   INTEGER NOT NULL,
    exercise_id   TEXT    NOT NULL,
    exercise_type TEXT    NOT NULL,
    attempt_id    TEXT    NOT NULL DEFAULT '',
    status        TEXT    NOT NULL DEFAULT 'pending',
    PRIMARY KEY (session_id, sequence_no)
);

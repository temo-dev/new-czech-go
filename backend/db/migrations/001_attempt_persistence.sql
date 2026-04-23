CREATE TABLE IF NOT EXISTS attempts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    exercise_id TEXT NOT NULL,
    exercise_type TEXT NOT NULL,
    status TEXT NOT NULL,
    attempt_no INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    recording_started_at TIMESTAMPTZ,
    recording_uploaded_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_code TEXT,
    readiness_level TEXT,
    client_platform TEXT NOT NULL,
    app_version TEXT,
    UNIQUE (user_id, exercise_id, attempt_no)
);

CREATE TABLE IF NOT EXISTS attempt_audio (
    attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
    storage_key TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    sample_rate_hz INTEGER,
    channels INTEGER,
    file_size_bytes INTEGER NOT NULL,
    stored_file_path TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS attempt_transcripts (
    attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
    full_text TEXT NOT NULL,
    locale TEXT NOT NULL,
    confidence DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS attempt_feedback (
    attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
    payload JSONB NOT NULL
);

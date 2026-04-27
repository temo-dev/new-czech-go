-- Exercise audio: stores generated or uploaded audio metadata for listening exercises.
CREATE TABLE IF NOT EXISTS exercise_audio (
    exercise_id  TEXT        PRIMARY KEY,
    storage_key  TEXT        NOT NULL,
    mime_type    TEXT        NOT NULL DEFAULT 'audio/mpeg',
    source_type  TEXT        NOT NULL DEFAULT 'polly',  -- 'polly' | 'upload'
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

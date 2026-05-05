-- V18: per-sentence audio for psani_3_dictation. Separate table from
-- exercise_audio so dictation's N rows per exercise (one per sentence) do not
-- conflict with the existing exercise_audio.exercise_id PRIMARY KEY which
-- assumes a single audio asset per exercise.
CREATE TABLE IF NOT EXISTS exercise_sentence_audio (
    exercise_id  TEXT        NOT NULL,
    sentence_idx INT         NOT NULL,
    storage_key  TEXT        NOT NULL,
    mime_type    TEXT        NOT NULL DEFAULT 'audio/mpeg',
    source_type  TEXT        NOT NULL DEFAULT 'polly',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (exercise_id, sentence_idx)
);

CREATE INDEX IF NOT EXISTS idx_exercise_sentence_audio_exercise
    ON exercise_sentence_audio (exercise_id);

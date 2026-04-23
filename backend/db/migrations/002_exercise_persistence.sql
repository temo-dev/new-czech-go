CREATE TABLE IF NOT EXISTS exercises (
    id TEXT PRIMARY KEY,
    module_id TEXT NOT NULL,
    exercise_type TEXT NOT NULL,
    title TEXT NOT NULL,
    short_instruction TEXT NOT NULL,
    learner_instruction TEXT NOT NULL,
    estimated_duration_sec INTEGER NOT NULL,
    prep_time_sec INTEGER,
    recording_time_limit_sec INTEGER,
    sample_answer_enabled BOOLEAN NOT NULL,
    status TEXT NOT NULL,
    sequence_no INTEGER,
    prompt_json JSONB,
    assets_json JSONB,
    detail_json JSONB,
    scoring_template_preview_json JSONB
);

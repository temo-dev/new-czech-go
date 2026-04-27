ALTER TABLE exercises
    ADD COLUMN IF NOT EXISTS sample_answer_text TEXT NOT NULL DEFAULT '';

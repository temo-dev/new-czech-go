-- V6: Track which generation job and source produced each exercise.
-- Nullable so existing exercises are unaffected.
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS source_type TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS source_id TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS generation_job_id TEXT;

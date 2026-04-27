-- Separate exercise pools: course exercises vs exam exercises.
-- pool='course' = bài luyện trong Course → Skill (default)
-- pool='exam'   = bài thi trong MockTest → Section
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS pool TEXT NOT NULL DEFAULT 'course';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS skill_id TEXT NOT NULL DEFAULT '';

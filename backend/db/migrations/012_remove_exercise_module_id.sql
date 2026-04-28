-- exercises.module_id is redundant: exercise → skill → module is the canonical path.
-- Storing module_id directly creates data inconsistency risk (exercise.module_id can
-- diverge from skill.module_id). skill_id is the single source of truth.
ALTER TABLE exercises DROP COLUMN IF EXISTS module_id;
CREATE INDEX IF NOT EXISTS idx_exercises_skill_id ON exercises(skill_id) WHERE skill_id <> '';

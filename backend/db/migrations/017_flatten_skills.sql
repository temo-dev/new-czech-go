-- Flatten skills table: exercises link directly to modules.
-- skill_kind is stored on exercises because matching/fill_blank/choice_word
-- are shared between tu_vung and ngu_phap — cannot be derived from exercise_type alone.

-- Step 1: exercises — add module_id + skill_kind, populate from skills JOIN, drop skill_id
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS module_id  TEXT NOT NULL DEFAULT '';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS skill_kind TEXT NOT NULL DEFAULT '';

UPDATE exercises e
SET module_id  = s.module_id,
    skill_kind = s.skill_kind
FROM skills s
WHERE s.id = e.skill_id
  AND e.skill_id <> '';

DROP INDEX IF EXISTS idx_exercises_skill_id;
ALTER TABLE exercises DROP COLUMN IF EXISTS skill_id;

CREATE INDEX IF NOT EXISTS idx_exercises_module_id    ON exercises(module_id);
CREATE INDEX IF NOT EXISTS idx_exercises_module_skill ON exercises(module_id, skill_kind);

-- Step 2: vocabulary_sets — add module_id, drop skill_id FK
ALTER TABLE vocabulary_sets ADD COLUMN IF NOT EXISTS module_id TEXT NOT NULL DEFAULT '';
ALTER TABLE vocabulary_sets DROP CONSTRAINT IF EXISTS vocabulary_sets_skill_id_fkey;
ALTER TABLE vocabulary_sets DROP COLUMN IF EXISTS skill_id;

-- Step 3: grammar_rules — add module_id, drop skill_id FK and index
ALTER TABLE grammar_rules ADD COLUMN IF NOT EXISTS module_id TEXT NOT NULL DEFAULT '';
ALTER TABLE grammar_rules DROP CONSTRAINT IF EXISTS grammar_rules_skill_id_fkey;
DROP INDEX IF EXISTS idx_grammar_rules_skill_id;
ALTER TABLE grammar_rules DROP COLUMN IF EXISTS skill_id;

-- Step 4: content_generation_jobs — drop nullable skill_id (module_id already present)
ALTER TABLE content_generation_jobs DROP COLUMN IF EXISTS skill_id;

-- Step 5: drop skills table (no FK references remain)
DROP TABLE IF EXISTS skills;

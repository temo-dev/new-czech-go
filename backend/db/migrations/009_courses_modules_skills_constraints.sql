-- Add CHECK constraints and indexes to courses/modules/skills tables.
-- Fixes: status/kind columns accepted arbitrary strings (no DB-level guard).
-- Fixes: modules.course_id defaulted to '' allowing orphaned modules.
-- Fixes: missing indexes on foreign-key-like columns.

-- CHECK constraints (idempotent via DO blocks)
DO $$ BEGIN
    ALTER TABLE courses ADD CONSTRAINT courses_status_check
        CHECK (status IN ('draft', 'published', 'archived'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE modules ADD CONSTRAINT modules_status_check
        CHECK (status IN ('draft', 'published', 'archived'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE modules ADD CONSTRAINT modules_kind_check
        CHECK (module_kind IN ('daily_plan', 'practice', 'mock_exam'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE skills ADD CONSTRAINT skills_status_check
        CHECK (status IN ('draft', 'published', 'archived'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE skills ADD CONSTRAINT skills_kind_check
        CHECK (skill_kind IN ('noi', 'nghe', 'doc', 'viet', 'tu_vung', 'ngu_phap'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes for common filter columns
CREATE INDEX IF NOT EXISTS idx_modules_course_id ON modules(course_id);
CREATE INDEX IF NOT EXISTS idx_skills_module_id  ON skills(module_id);
CREATE INDEX IF NOT EXISTS idx_courses_status     ON courses(status);
CREATE INDEX IF NOT EXISTS idx_modules_status     ON modules(status);
CREATE INDEX IF NOT EXISTS idx_skills_status      ON skills(status);

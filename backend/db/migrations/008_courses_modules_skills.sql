-- Persist courses, modules, and skills to Postgres so admin data
-- survives container restarts. Previously these were in-memory only,
-- causing hardcoded seed data to reappear on every compose-up.

CREATE TABLE IF NOT EXISTS courses (
    id          TEXT        PRIMARY KEY,
    slug        TEXT        NOT NULL DEFAULT '',
    title       TEXT        NOT NULL,
    description TEXT        NOT NULL DEFAULT '',
    status      TEXT        NOT NULL DEFAULT 'draft',
    sequence_no INTEGER     NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS modules (
    id          TEXT        PRIMARY KEY,
    course_id   TEXT        NOT NULL DEFAULT '',
    slug        TEXT        NOT NULL DEFAULT '',
    title       TEXT        NOT NULL,
    description TEXT        NOT NULL DEFAULT '',
    module_kind TEXT        NOT NULL DEFAULT 'daily_plan',
    sequence_no INTEGER     NOT NULL DEFAULT 0,
    status      TEXT        NOT NULL DEFAULT 'draft',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS skills (
    id          TEXT        PRIMARY KEY,
    module_id   TEXT        NOT NULL,
    skill_kind  TEXT        NOT NULL,
    title       TEXT        NOT NULL,
    sequence_no INTEGER     NOT NULL DEFAULT 0,
    status      TEXT        NOT NULL DEFAULT 'draft',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

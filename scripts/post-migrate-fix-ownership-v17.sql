-- V17 — Self-Serve Learner — RDS table-ownership fix.
--
-- Background: V11 documented that on RDS the goose/admin role that runs
-- the initial migration may differ from the runtime application role.
-- When that happens, runtime ALTER TABLE statements (e.g. the
-- `addColumnIfMissing` helper in backend/internal/store/postgres_migrate.go)
-- fail because non-owner roles cannot ALTER. Ownership must be transferred
-- exactly once after the V17 tables land.
--
-- Run this script ONCE on the production database, AFTER applying
-- 023_users.sql, BEFORE the runtime backend starts attempting any
-- subsequent column-adds against these tables.
--
-- Local / staging databases that use the same role for migrations and
-- runtime can still safely run this script — the DO block silently skips
-- tables that don't exist yet, and re-assigning ownership to the same
-- role is a no-op.
--
-- Usage:
--
--   psql "$DATABASE_URL" -v app_user=czech_user -f post-migrate-fix-ownership-v17.sql
--
-- The :app_user psql variable defaults to czech_user; override with -v
-- if your runtime role is named differently. A failed run leaves the
-- database untouched (single transaction).

\set app_user czech_user

BEGIN;

DO $$
DECLARE
    target_role TEXT := current_setting('myapp.app_user', TRUE);
    v17_table   TEXT;
BEGIN
    IF target_role IS NULL OR target_role = '' THEN
        target_role := :'app_user';
    END IF;

    -- Verify the role exists before issuing any ALTER. ALTER OWNER TO a
    -- non-existent role fails with a confusing message; this guard makes
    -- the failure mode explicit.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = target_role) THEN
        RAISE EXCEPTION 'role % does not exist; grant CREATE ROLE first or override -v app_user', target_role;
    END IF;

    FOREACH v17_table IN ARRAY ARRAY[
        'users',
        'auth_tokens',
        'streak_days',
        'pro_purchases',
        'daily_usage'
    ]
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = current_schema() AND table_name = v17_table
        ) THEN
            EXECUTE format('ALTER TABLE %I OWNER TO %I', v17_table, target_role);
            RAISE NOTICE 'transferred ownership of % to %', v17_table, target_role;
        ELSE
            RAISE NOTICE 'skipping %: not present in current schema', v17_table;
        END IF;
    END LOOP;
END
$$;

COMMIT;

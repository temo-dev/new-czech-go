-- V21 — one-shot backfill for users that existed before migration 025.
--
-- Migration 025 added users.current_level / unlocked_levels with new-user
-- defaults ('a0' / ARRAY['a0']). Pre-V21 users have already used the app
-- and should not be sent through onboarding from scratch — promote them
-- to the existing product scope (a2) with all lower levels unlocked.
--
-- Idempotency: the WHERE clause matches only users that
--   (a) are still on the migration default (current_level = 'a0'), AND
--   (b) have never taken a placement test (placement_taken_at IS NULL), AND
--   (c) signed up before V21 shipped (created_at < 2026-05-07).
-- All three conditions become false the moment a user goes through real
-- V21 onboarding, so re-running this migration is a no-op.
--
-- S8 — the explicit created_at guard prevents a race where a brand-new
-- A0 sign-up landing between migration apply and first placement gets
-- auto-promoted to a2. Pre-S8 the only guard was placement_taken_at
-- IS NULL, which is also true for those fresh accounts.
--
-- Fresh databases match no rows (no users exist yet) so this also stays a
-- no-op for greenfield deploys; new sign-ups continue to start on a0.

UPDATE users
   SET current_level = 'a2',
       unlocked_levels = ARRAY['a0','a1','a2'],
       updated_at = now()
 WHERE current_level = 'a0'
   AND placement_taken_at IS NULL
   AND created_at < '2026-05-07T00:00:00Z'::timestamptz;

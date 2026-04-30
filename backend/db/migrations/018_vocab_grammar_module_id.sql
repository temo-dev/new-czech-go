-- Fix missing module_id on vocabulary_sets and grammar_rules.
-- Migration 017 dropped skill_id but did not add module_id to these tables.
-- Existing rows get module_id = '' (no skill link survives to recover from).

ALTER TABLE vocabulary_sets ADD COLUMN IF NOT EXISTS module_id TEXT NOT NULL DEFAULT '';
ALTER TABLE grammar_rules   ADD COLUMN IF NOT EXISTS module_id TEXT NOT NULL DEFAULT '';

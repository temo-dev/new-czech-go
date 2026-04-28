-- V6: Grammar rules for LLM-assisted exercise generation.
CREATE TABLE IF NOT EXISTS grammar_rules (
    id TEXT PRIMARY KEY,
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'A2',
    explanation_vi TEXT NOT NULL DEFAULT '',
    rule_table_json JSONB,
    constraints_text TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_grammar_rules_skill_id ON grammar_rules(skill_id);

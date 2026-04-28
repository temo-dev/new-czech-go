-- V6: Content generation jobs for async LLM-assisted exercise authoring.
-- status lifecycle: pending → running → generated | failed → rejected | published
CREATE TABLE IF NOT EXISTS content_generation_jobs (
    id TEXT PRIMARY KEY,
    module_id TEXT NOT NULL,
    skill_id TEXT,
    source_type TEXT NOT NULL,   -- vocabulary_set | grammar_rule
    source_id TEXT NOT NULL,
    requested_by TEXT NOT NULL DEFAULT 'admin',
    input_payload_json JSONB NOT NULL DEFAULT '{}',
    generated_payload_json JSONB,
    edited_payload_json JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    provider TEXT NOT NULL DEFAULT 'claude',
    model TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
    input_tokens INTEGER,
    output_tokens INTEGER,
    estimated_cost_usd NUMERIC(10,6),
    duration_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_gen_jobs_module_status
    ON content_generation_jobs(module_id, requested_by, status);

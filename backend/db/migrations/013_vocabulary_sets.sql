-- V6: Vocabulary sets and items for LLM-assisted content generation.
CREATE TABLE IF NOT EXISTS vocabulary_sets (
    id TEXT PRIMARY KEY,
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'A2',
    explanation_lang TEXT NOT NULL DEFAULT 'vi',
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vocabulary_items (
    id TEXT PRIMARY KEY,
    set_id TEXT NOT NULL REFERENCES vocabulary_sets(id) ON DELETE CASCADE,
    term TEXT NOT NULL,
    meaning TEXT NOT NULL,
    part_of_speech TEXT NOT NULL DEFAULT '',
    example_sentence TEXT NOT NULL DEFAULT '',
    example_translation TEXT NOT NULL DEFAULT '',
    sequence_no INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vocabulary_items_set_id ON vocabulary_items(set_id);

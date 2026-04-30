-- Add image_asset_id to grammar_rules for media enrichment (V11)
ALTER TABLE grammar_rules ADD COLUMN IF NOT EXISTS image_asset_id TEXT NOT NULL DEFAULT '';

-- Add image_asset_id to vocabulary_items for media enrichment (V11)
ALTER TABLE vocabulary_items ADD COLUMN IF NOT EXISTS image_asset_id TEXT NOT NULL DEFAULT '';

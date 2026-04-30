-- Add banner_image_id to courses for course card banner images (V11)
ALTER TABLE courses ADD COLUMN IF NOT EXISTS banner_image_id TEXT NOT NULL DEFAULT '';

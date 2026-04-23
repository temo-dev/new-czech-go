ALTER TABLE attempts
ADD COLUMN IF NOT EXISTS pending_upload_storage_key TEXT;

ALTER TABLE attempts
ADD COLUMN IF NOT EXISTS upload_target_issued_at TIMESTAMPTZ;

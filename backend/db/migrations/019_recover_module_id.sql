-- Recovery: restore module_id mappings lost due to partial migration state.
-- Apply after 017/018 on instances where module_id was reset to ''.
-- Module UUIDs derived from original skills table data.

-- exercises: restore module_id from skill_kind (known mappings from original skills data)
UPDATE exercises SET module_id = 'module-651cd7dd-5cec-49d3-b686-1e593ed584d4'
  WHERE skill_kind IN ('noi', 'tu_vung', 'ngu_phap') AND module_id = '';

UPDATE exercises SET module_id = 'module-0a3a0609-85d9-4855-affc-bdbc201bf09b'
  WHERE skill_kind = 'nghe' AND module_id = '';

UPDATE exercises SET module_id = 'module-0845b567-d004-4b64-8efa-c13de22b1bfa'
  WHERE skill_kind = 'doc' AND module_id = '';

UPDATE exercises SET module_id = 'module-14762c14-102c-42fa-9636-b76a095ad4e1'
  WHERE skill_kind = 'viet' AND module_id = '';

-- vocabulary_sets and grammar_rules: all were in module-651cd7dd
UPDATE vocabulary_sets SET module_id = 'module-651cd7dd-5cec-49d3-b686-1e593ed584d4'
  WHERE module_id = '';

UPDATE grammar_rules SET module_id = 'module-651cd7dd-5cec-49d3-b686-1e593ed584d4'
  WHERE module_id = '';

-- Drop skill_id if it reappeared
ALTER TABLE exercises DROP COLUMN IF EXISTS skill_id;

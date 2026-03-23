-- 004_phase0_foundation.sql
-- Phase 0 foundation: admin_role expansion, user_role cleanup,
-- platform_config, llm_usage_log, fcm_token, primary_specialty_id, wristband_issued_at
--
-- Changes:
--   1. admin_role enum: add 'moderator' and 'eventOps' values
--   2. user_role enum: remove 'venueStaff' (migrate existing rows to 'user' first)
--   3. platform_config table + default seed rows
--   4. llm_usage_log table
--   5. users.fcm_token column (nullable TEXT)
--   6. users.primary_specialty_id column (nullable FK to specialties)
--   7. tickets.wristband_issued_at column (nullable TIMESTAMPTZ)
--
-- Idempotency: ADD VALUE IF NOT EXISTS, ADD COLUMN IF NOT EXISTS, CREATE TABLE IF NOT EXISTS,
-- ON CONFLICT DO NOTHING for seed inserts. user_role recreation is guarded by a PL/pgSQL block.
--
-- NOTE: Do not add top-level BEGIN/COMMIT here; scripts/migrate.js wraps each migration in a transaction.

-- ============================================================
-- 1. Expand admin_role enum
-- ============================================================

ALTER TYPE admin_role ADD VALUE IF NOT EXISTS 'moderator';
ALTER TYPE admin_role ADD VALUE IF NOT EXISTS 'eventOps';

-- ============================================================
-- 2. Clean up user_role enum — remove 'venueStaff'
--    PostgreSQL requires type recreation to remove an enum value.
--    Guard the whole block with an existence check so it is idempotent.
-- ============================================================

DO $$
BEGIN
  -- Only proceed if venueStaff still exists in the enum
  IF EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'user_role'
      AND e.enumlabel = 'venueStaff'
  ) THEN
    -- Step 1: migrate any venueStaff rows to 'user'
    UPDATE users SET role = 'user' WHERE role = 'venueStaff';

    -- Step 2: create replacement enum
    CREATE TYPE user_role_new AS ENUM ('user', 'platformAdmin');

    -- Step 3: drop the column default (it references the old type, which blocks the ALTER)
    ALTER TABLE users ALTER COLUMN role DROP DEFAULT;

    -- Step 4: swap the column type
    ALTER TABLE users
      ALTER COLUMN role TYPE user_role_new
      USING role::text::user_role_new;

    -- Step 5: drop old type and rename
    DROP TYPE user_role;
    ALTER TYPE user_role_new RENAME TO user_role;

    -- Step 6: restore the default (now referencing the renamed type)
    ALTER TABLE users ALTER COLUMN role SET DEFAULT 'user';
  END IF;
END $$;

-- ============================================================
-- 3. platform_config table
-- ============================================================

CREATE TABLE IF NOT EXISTS platform_config (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  description TEXT,
  updated_by  UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Default seed rows (idempotent via ON CONFLICT DO NOTHING)
INSERT INTO platform_config (key, value, description) VALUES
  ('llm_moderation_model_fast',                '"claude-haiku-4-5-20251001"', 'Model used for fast-pass moderation (Haiku)'),
  ('llm_moderation_model_review',              '"claude-sonnet-4-6"',         'Model used for borderline content review (Sonnet)'),
  ('llm_moderation_confidence_auto_approve',   '0.9',                         'Confidence threshold above which posts are auto-approved'),
  ('llm_moderation_confidence_auto_reject',    '0.9',                         'Confidence threshold above which posts are auto-rejected (violation confidence)'),
  ('llm_moderation_confidence_human_floor',    '0.3',                         'Confidence below this sends to human review queue'),
  ('feature_flag_who_is_here',                 'false',                       'Enable Who''s Here / Who''s Going tabs on event detail'),
  ('feature_flag_jobs_board',                  'false',                       'Enable Jobs Board tab in social app'),
  ('feature_flag_push_notifications',          'false',                       'Enable FCM push notifications')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 4. llm_usage_log table
-- ============================================================

CREATE TABLE IF NOT EXISTS llm_usage_log (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  feature       TEXT        NOT NULL,
  model         TEXT        NOT NULL,
  input_tokens  INT,
  output_tokens INT,
  latency_ms    INT,
  success       BOOLEAN     NOT NULL,
  error         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. users.fcm_token column
-- ============================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- ============================================================
-- 6. users.primary_specialty_id column
-- ============================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS
  primary_specialty_id VARCHAR(50) REFERENCES specialties(id) ON DELETE SET NULL;

-- ============================================================
-- 7. tickets.wristband_issued_at column
-- ============================================================

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS wristband_issued_at TIMESTAMPTZ;

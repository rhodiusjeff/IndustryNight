-- 002_audit_security_foundation.sql
-- Phase 1 security audit schema enhancements.

DO $$
BEGIN
  CREATE TYPE actor_type AS ENUM ('user', 'admin', 'system');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE audit_result AS ENUM ('success', 'failure');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE audit_log
  ADD COLUMN IF NOT EXISTS admin_actor_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS actor_type actor_type NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS result audit_result NOT NULL DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS failure_reason VARCHAR(100),
  ADD COLUMN IF NOT EXISTS request_id UUID,
  ADD COLUMN IF NOT EXISTS route VARCHAR(255),
  ADD COLUMN IF NOT EXISTS method VARCHAR(10),
  ADD COLUMN IF NOT EXISTS status_code INTEGER,
  ADD COLUMN IF NOT EXISTS source_ip INET,
  ADD COLUMN IF NOT EXISTS user_agent TEXT,
  ADD COLUMN IF NOT EXISTS environment VARCHAR(20) NOT NULL DEFAULT 'development',
  ADD COLUMN IF NOT EXISTS metadata_version INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

UPDATE audit_log
SET actor_type = 'user'
WHERE actor_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ck_audit_log_actor_identity'
  ) THEN
    ALTER TABLE audit_log
    ADD CONSTRAINT ck_audit_log_actor_identity
    CHECK (
      (actor_type = 'user' AND actor_id IS NOT NULL AND admin_actor_id IS NULL)
      OR (actor_type = 'admin' AND actor_id IS NULL AND admin_actor_id IS NOT NULL)
      OR (actor_type = 'system' AND actor_id IS NULL AND admin_actor_id IS NULL)
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ck_audit_log_environment'
  ) THEN
    ALTER TABLE audit_log
    ADD CONSTRAINT ck_audit_log_environment
    CHECK (environment IN ('development', 'production', 'test'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_log_admin_actor ON audit_log(admin_actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_result ON audit_log(result);
CREATE INDEX IF NOT EXISTS idx_audit_log_failure_reason ON audit_log(failure_reason);
CREATE INDEX IF NOT EXISTS idx_audit_log_request_id ON audit_log(request_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_occurred_at ON audit_log(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action_result_time ON audit_log(action, result, occurred_at DESC);

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is immutable';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_update ON audit_log;
CREATE TRIGGER trg_prevent_audit_log_update
  BEFORE UPDATE ON audit_log
  FOR EACH ROW
  EXECUTE FUNCTION prevent_audit_log_mutation();

DROP TRIGGER IF EXISTS trg_prevent_audit_log_delete ON audit_log;
CREATE TRIGGER trg_prevent_audit_log_delete
  BEFORE DELETE ON audit_log
  FOR EACH ROW
  EXECUTE FUNCTION prevent_audit_log_mutation();

-- 005_fix_audit_log_user_delete_cascade.sql
--
-- Bug: DELETE FROM users fails with "audit_log is immutable" when the user
-- has any audit_log entries. Root cause: migration 002 installed an immutability
-- trigger (prevent_audit_log_mutation) that raises on ANY UPDATE, including
-- the ON DELETE SET NULL FK cascade that PostgreSQL performs on audit_log.actor_id
-- when a referenced user is deleted. Additionally, the ck_audit_log_actor_identity
-- CHECK constraint requires (actor_type='user' AND actor_id IS NOT NULL), so a
-- plain SET NULL would also violate the check.
--
-- Fix: Replace prevent_audit_log_mutation() with a version that permits the
-- one legitimate "soft mutation" — tombstoning the actor reference when a user
-- is deleted (actor_id non-null → NULL, all other columns untouched). The
-- function simultaneously promotes actor_type to 'system' to satisfy the CHECK
-- constraint. All other mutations continue to raise an exception.

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  -- Permit FK cascade from ON DELETE SET NULL on audit_log.actor_id.
  -- Pattern: only actor_id changes (from non-null to NULL); every other
  -- business column is untouched. We promote actor_type to 'system' so
  -- the ck_audit_log_actor_identity CHECK constraint remains satisfied.
  IF TG_OP = 'UPDATE'
     AND OLD.actor_id IS NOT NULL
     AND NEW.actor_id IS NULL
     AND NEW.action            IS NOT DISTINCT FROM OLD.action
     AND NEW.entity_type       IS NOT DISTINCT FROM OLD.entity_type
     AND NEW.entity_id         IS NOT DISTINCT FROM OLD.entity_id
     AND NEW.admin_actor_id    IS NOT DISTINCT FROM OLD.admin_actor_id
  THEN
    NEW.actor_type := 'system';
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'audit_log is immutable';
END;
$$ LANGUAGE plpgsql;

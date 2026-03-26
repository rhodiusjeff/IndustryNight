-- 006_fix_audit_log_admin_delete_cascade.sql
--
-- Bug: DELETE FROM admin_users fails with "audit_log is immutable" when the
-- admin has any audit_log entries where admin_actor_id references them.
-- Root cause: migration 005 extended prevent_audit_log_mutation() to permit
-- the actor_id FK cascade (users → audit_log.actor_id SET NULL) but did NOT
-- cover the parallel admin_actor_id FK cascade (admin_users → audit_log.admin_actor_id
-- SET NULL). Both columns have the same ON DELETE SET NULL behaviour; both
-- trigger the immutability check.
--
-- Fix: Extend prevent_audit_log_mutation() with a second permitted path — the
-- admin_actor_id non-null → NULL cascade. Unlike the user case, no actor_type
-- promotion is required because the ck_audit_log_actor_identity CHECK
-- constraint only governs actor_type/actor_id, not admin_actor_id.

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

  -- Permit FK cascade from ON DELETE SET NULL on audit_log.admin_actor_id.
  -- Pattern: only admin_actor_id changes (from non-null to NULL); every
  -- other business column is untouched. actor_type is not affected because
  -- the CHECK constraint does not govern admin_actor_id.
  IF TG_OP = 'UPDATE'
     AND OLD.admin_actor_id IS NOT NULL
     AND NEW.admin_actor_id IS NULL
     AND NEW.action         IS NOT DISTINCT FROM OLD.action
     AND NEW.entity_type    IS NOT DISTINCT FROM OLD.entity_type
     AND NEW.entity_id      IS NOT DISTINCT FROM OLD.entity_id
     AND NEW.actor_id       IS NOT DISTINCT FROM OLD.actor_id
  THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'audit_log is immutable';
END;
$$ LANGUAGE plpgsql;

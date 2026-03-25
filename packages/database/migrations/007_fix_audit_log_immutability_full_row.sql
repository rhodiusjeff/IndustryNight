-- 007_fix_audit_log_immutability_full_row.sql
--
-- Two bugs addressed in this migration:
--
-- Bug 1: DELETE FROM admin_users still fails with "audit_log is immutable"
-- after migration 006. Root cause: migration 006 added the admin_actor_id
-- cascade path but forgot actor_type promotion. When admin_actor_id is
-- cascaded to NULL, the row has actor_type='admin'. After the cascade:
-- actor_type='admin', actor_id=NULL, admin_actor_id=NULL — which satisfies
-- none of the three ck_audit_log_actor_identity branches:
--   (user AND actor_id NOT NULL AND admin_actor_id IS NULL)    → no
--   (admin AND actor_id IS NULL AND admin_actor_id NOT NULL)   → no (admin_actor_id is now NULL)
--   (system AND actor_id IS NULL AND admin_actor_id IS NULL)   → no (actor_type is still 'admin')
-- Fix: promote actor_type to 'system' in the admin_actor_id branch too.
--
-- Bug 2: Both permitted UPDATE branches in migrations 005 and 006 only compared
-- a subset of audit_log columns (action/entity_type/entity_id/correlated FK).
-- Other columns (old_values/new_values/metadata/result/request_id/etc) could
-- be mutated in the same UPDATE alongside a FK-null and bypass the trigger.
-- Fix: Use a full NEW IS DISTINCT FROM OLD comparison, temporarily restoring
-- the changing columns to their OLD values to isolate the check, then
-- re-applying the intended new values before returning.

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id   audit_log.actor_id%TYPE;
  v_actor_type audit_log.actor_type%TYPE;
BEGIN
  -- Permit FK cascade: ON DELETE SET NULL on audit_log.actor_id (user deleted).
  -- The row must change ONLY actor_id (NULL) and actor_type ('system').
  -- Every other column must be identical to confirm this is a pure FK cascade.
  IF TG_OP = 'UPDATE'
     AND OLD.actor_id IS NOT NULL
     AND NEW.actor_id IS NULL
  THEN
    -- Save intended final values.
    v_actor_id   := NEW.actor_id;   -- will be NULL
    v_actor_type := 'system';

    -- Temporarily restore actor identity to OLD values for full-row comparison.
    NEW.actor_id   := OLD.actor_id;
    NEW.actor_type := OLD.actor_type;

    -- If any other column changed, this is not a pure FK cascade — reject it.
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'audit_log is immutable';
    END IF;

    -- Apply the intended tombstoned actor identity.
    NEW.actor_id   := v_actor_id;
    NEW.actor_type := v_actor_type;
    RETURN NEW;
  END IF;

  -- Permit FK cascade: ON DELETE SET NULL on audit_log.admin_actor_id (admin deleted).
  -- The row must change ONLY admin_actor_id (NULL) and actor_type ('system').
  -- Every other column must be identical to confirm this is a pure FK cascade.
  IF TG_OP = 'UPDATE'
     AND OLD.admin_actor_id IS NOT NULL
     AND NEW.admin_actor_id IS NULL
  THEN
    -- Save intended final values.
    v_actor_id   := NEW.admin_actor_id; -- will be NULL (reuse var for clarity)
    v_actor_type := 'system';

    -- Temporarily restore admin_actor_id and actor_type to OLD values for full-row comparison.
    NEW.admin_actor_id := OLD.admin_actor_id;
    NEW.actor_type     := OLD.actor_type;

    -- If any other column changed, this is not a pure FK cascade — reject it.
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'audit_log is immutable';
    END IF;

    -- Apply the intended tombstoned actor identity.
    NEW.admin_actor_id := NULL;
    NEW.actor_type     := v_actor_type;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'audit_log is immutable';
END;
$$ LANGUAGE plpgsql;

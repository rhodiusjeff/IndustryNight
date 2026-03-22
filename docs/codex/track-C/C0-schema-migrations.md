# [Track-C0] Phase 0 Schema Migrations — Foundation

**Track:** C (Backend + Schema)
**Sequence:** 1 of 5 in Track C
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← preferred if running inside OpenAI Codex platform; terminal-first workflow (psql, node scripts, grep verification) is where GPT-5.3-Codex's Terminal-Bench advantage is most tangible
**A/B Test:** Yes ⚡ — run both models on `feature/C0-schema-foundation/claude` and `feature/C0-schema-foundation/gpt`; adversarial panel review before merging to `integration`
**Estimated Effort:** Small (2-4 hours)
**Dependencies:** None — this is a root prompt. All other tracks depend on this completing successfully.

---

## Context

Read these before writing any SQL or code:

- `CLAUDE.md` — full project reference (database section, enum types, tables inventory)
- `docs/product/master_plan_v2.md` — Section 3.4 "Schema Migrations Required" (Phase 0 group)
- `packages/database/migrations/001_baseline_schema.sql` — current schema baseline
- `packages/database/migrations/` — existing migration files (understand naming convention)
- `scripts/migrate.js` — migration runner (understand how `_migrations` table works)

---

## Goal

Create and apply a single SQL migration file (`002_phase0_foundation.sql`) that adds the seven schema changes required before any other development work can proceed. These changes are additive only — no existing columns, tables, or enum values are modified in a breaking way. The migration must be idempotent (safe to re-run).

---

## Acceptance Criteria

- [ ] Migration file exists at `packages/database/migrations/002_phase0_foundation.sql`
- [ ] `admin_role` enum has values `platformAdmin`, `moderator`, `eventOps` (adds moderator + eventOps)
- [ ] `user_role` enum no longer contains `venueStaff` (removed; existing rows updated to `user` before removal)
- [ ] `platform_config` table exists with columns: `key TEXT PRIMARY KEY`, `value JSONB NOT NULL`, `description TEXT`, `updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- [ ] `llm_usage_log` table exists with columns: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `feature TEXT NOT NULL`, `model TEXT NOT NULL`, `input_tokens INT`, `output_tokens INT`, `latency_ms INT`, `success BOOLEAN NOT NULL`, `error TEXT`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- [ ] `users.fcm_token TEXT` column exists (nullable)
- [ ] `users.primary_specialty_id UUID REFERENCES specialties(id) ON DELETE SET NULL` column exists (nullable)
- [ ] `tickets.wristband_issued_at TIMESTAMPTZ` column exists (nullable)
- [ ] Migration is recorded in `_migrations` table after running `node scripts/migrate.js`
- [ ] `node scripts/migrate.js --dry-run` shows the migration as pending before run, and as applied after run
- [ ] `node scripts/migrate.js` (re-run) is a no-op (idempotent via `_migrations` check)
- [ ] All existing data is preserved — zero rows deleted or corrupted
- [ ] Existing admin_users with `admin_role = 'platformAdmin'` are unaffected by the enum expansion

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin, I want to be assigned `moderator` or `eventOps` roles so that I can give venue staff and content moderators scoped access without full admin privileges | Requires new enum values to exist |
| Event Ops staff | As an eventOps admin user, I want `wristband_issued_at` to be tracked so that the Event Ops screen can show real-time wristband confirmation status | |
| Social user | As a social user, I want my primary specialty to be stored separately from my full specialty list so that profile displays can show it prominently | |
| Social user | As a social user, I want my FCM device token stored so that push notifications can reach my device | Optional at signup; updated on first FCM registration |
| System | As the LLM pipeline, I want to write call telemetry to `llm_usage_log` so that cost and performance can be monitored | Inserts per-call, no foreign key constraints for resilience |
| System | As the admin UI, I want to read and write `platform_config` so that operators can adjust LLM thresholds and feature flags without code deploys | |

---

## Technical Spec

### Enum handling strategy

PostgreSQL does not support removing values from an existing enum without recreating it. The correct approach for removing `venueStaff` from `user_role`:

```sql
-- Step 1: Update any existing rows that use venueStaff
UPDATE users SET role = 'user' WHERE role = 'venueStaff';

-- Step 2: Create a new enum without venueStaff
CREATE TYPE user_role_new AS ENUM ('user', 'platformAdmin');

-- Step 3: Alter column to use new type
ALTER TABLE users ALTER COLUMN role TYPE user_role_new USING role::text::user_role_new;

-- Step 4: Drop old type and rename
DROP TYPE user_role;
ALTER TYPE user_role_new RENAME TO user_role;
```

For adding values to `admin_role`:
```sql
ALTER TYPE admin_role ADD VALUE IF NOT EXISTS 'moderator';
ALTER TYPE admin_role ADD VALUE IF NOT EXISTS 'eventOps';
```

Note: `ADD VALUE IF NOT EXISTS` is idempotent. Use it for all enum additions.

### Migration file structure

Follow the pattern in `001_baseline_schema.sql`. Each section should be clearly commented. The migration runner checks the `_migrations` table by filename — the file must have a unique name.

```sql
-- 002_phase0_foundation.sql
-- Phase 0 foundation: admin_role expansion, user_role cleanup,
-- platform_config, llm_usage_log, fcm_token, primary_specialty_id, wristband_issued_at

BEGIN;

-- [each change in its own commented block]

COMMIT;
```

### Default seed data for platform_config

After creating the table, insert default configuration rows:

```sql
INSERT INTO platform_config (key, value, description) VALUES
  ('llm_moderation_model_fast', '"claude-haiku-4-5-20251001"', 'Model used for fast-pass moderation (Haiku)'),
  ('llm_moderation_model_review', '"claude-sonnet-4-6"', 'Model used for borderline content review (Sonnet)'),
  ('llm_moderation_confidence_auto_approve', '0.9', 'Confidence threshold above which posts are auto-approved'),
  ('llm_moderation_confidence_auto_reject', '0.9', 'Confidence threshold above which posts are auto-rejected (violation confidence)'),
  ('llm_moderation_confidence_human_floor', '0.3', 'Confidence below this sends to human review queue'),
  ('feature_flag_who_is_here', 'false', 'Enable Who''s Here / Who''s Going tabs on event detail'),
  ('feature_flag_jobs_board', 'false', 'Enable Jobs Board tab in social app'),
  ('feature_flag_push_notifications', 'false', 'Enable FCM push notifications')
ON CONFLICT (key) DO NOTHING;
```

### Column additions — use IF NOT EXISTS pattern

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_specialty_id UUID REFERENCES specialties(id) ON DELETE SET NULL;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS wristband_issued_at TIMESTAMPTZ;
```

### No Dart model changes in this prompt

This prompt is database-only. Do NOT modify any Flutter Dart model files, API routes, or TypeScript files. Those are handled in subsequent track prompts that depend on C0.

---

## Test Suite

### Manual Verification (run after migration)

```bash
# Start port-forward to dev DB
./scripts/pf-db.sh start

# Run migration
DB_PASSWORD=xxx node scripts/migrate.js

# Verify migration recorded
psql $DATABASE_URL -c "SELECT filename, applied_at FROM _migrations ORDER BY applied_at;"
# Expected: 002_phase0_foundation.sql appears with current timestamp

# Verify enum values
psql $DATABASE_URL -c "SELECT unnest(enum_range(NULL::admin_role));"
# Expected: platformAdmin, moderator, eventOps

psql $DATABASE_URL -c "SELECT unnest(enum_range(NULL::user_role));"
# Expected: user, platformAdmin (no venueStaff)

# Verify new tables exist
psql $DATABASE_URL -c "\d platform_config"
psql $DATABASE_URL -c "\d llm_usage_log"

# Verify new columns
psql $DATABASE_URL -c "\d users" | grep -E "fcm_token|primary_specialty"
psql $DATABASE_URL -c "\d tickets" | grep wristband

# Verify default config rows
psql $DATABASE_URL -c "SELECT key, value FROM platform_config ORDER BY key;"
# Expected: 8 rows matching the seed data above

# Verify idempotency
node scripts/migrate.js
# Expected: "002_phase0_foundation.sql already applied, skipping"
```

### Automated Test (add to `packages/api/src/__tests__/schema.test.ts`)

Create or add to a schema verification test file:

```typescript
// packages/api/src/__tests__/schema.test.ts
describe('Phase 0 schema migration', () => {
  it('admin_role enum contains moderator and eventOps', async () => {
    const result = await db.query(
      `SELECT unnest(enum_range(NULL::admin_role)) AS val`
    );
    const values = result.rows.map(r => r.val);
    expect(values).toContain('moderator');
    expect(values).toContain('eventOps');
    expect(values).toContain('platformAdmin');
  });

  it('user_role enum does not contain venueStaff', async () => {
    const result = await db.query(
      `SELECT unnest(enum_range(NULL::user_role)) AS val`
    );
    const values = result.rows.map(r => r.val);
    expect(values).not.toContain('venueStaff');
  });

  it('platform_config table exists and has default rows', async () => {
    const result = await db.query(`SELECT COUNT(*) FROM platform_config`);
    expect(parseInt(result.rows[0].count)).toBeGreaterThanOrEqual(8);
  });

  it('llm_usage_log table exists', async () => {
    // Insert a row, verify it persists
    await db.query(`
      INSERT INTO llm_usage_log (feature, model, input_tokens, output_tokens, latency_ms, success)
      VALUES ('test', 'test-model', 100, 50, 200, true)
    `);
    const result = await db.query(
      `SELECT COUNT(*) FROM llm_usage_log WHERE feature = 'test'`
    );
    expect(parseInt(result.rows[0].count)).toBe(1);
  });

  it('users table has fcm_token column', async () => {
    const result = await db.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'fcm_token'
    `);
    expect(result.rows.length).toBe(1);
  });

  it('users table has primary_specialty_id column', async () => {
    const result = await db.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'primary_specialty_id'
    `);
    expect(result.rows.length).toBe(1);
  });

  it('tickets table has wristband_issued_at column', async () => {
    const result = await db.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'tickets' AND column_name = 'wristband_issued_at'
    `);
    expect(result.rows.length).toBe(1);
  });
});
```

### CI/CD Integration

This test should be added to `packages/api/src/__tests__/schema.test.ts` and will run automatically in `api.yml` via `npx jest`. The test uses the testcontainers PostgreSQL setup already in place — the migration must be applied to the test container as part of the test setup (testcontainers runs all migrations in order).

**Smoke test (post-deploy check):**
```bash
# Add to deploy-api.sh post-deploy smoke test
curl -sf "$API_URL/health" | jq -e '.status == "ok"' || exit 1
# Schema changes don't need a dedicated smoke endpoint — health check DB ping suffices
```

---

## Definition of Done

- [ ] `packages/database/migrations/002_phase0_foundation.sql` committed
- [ ] Migration applied successfully to dev DB
- [ ] All manual verification commands pass
- [ ] Schema test file added/updated in `packages/api/src/__tests__/schema.test.ts`
- [ ] Tests pass in testcontainers environment (`cd packages/api && npx jest schema`)
- [ ] No existing tests broken by enum changes
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff
- [ ] (A/B) Adversarial panel review complete — see `docs/codex/reviews/C0-adversarial-review.md`

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/C0-schema-foundation/[claude|gpt]`
**Model used:** —
**Date completed:** —

### What I implemented exactly as specced
-

### What I deviated from the spec and why
-

### What I deferred or left incomplete
-

### Technical debt introduced
-

### What the next prompt in this track (C1) should know
-

---

## Interrogative Session

**Q1: Does the migration apply cleanly and do the manual verification commands all pass as expected?**
> Jeff:

**Q2: Does anything about the schema choices feel wrong — naming, types, constraints — that the acceptance criteria wouldn't catch?**
> Jeff:

**Q3: Any concerns before this goes to adversarial review?**
> Jeff:

**Ready for review:** ☐ Yes

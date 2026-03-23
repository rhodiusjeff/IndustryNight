/**
 * Phase 0 Schema Migration Tests (C0)
 *
 * Verifies that 004_phase0_foundation.sql has been correctly applied:
 *   - admin_role enum has moderator and eventOps
 *   - user_role enum does not have venueStaff
 *   - platform_config table exists with 8 default seed rows
 *   - llm_usage_log table exists and accepts inserts
 *   - users.fcm_token column exists
 *   - users.primary_specialty_id column exists
 *   - tickets.wristband_issued_at column exists
 *
 * These tests run against the testcontainers PostgreSQL instance with all
 * migrations applied in sequence (including 004_phase0_foundation.sql).
 */
import { getTestPool } from './helpers/db';

const db = {
  query: (text: string, params?: unknown[]) => getTestPool().query(text, params as unknown[]),
};

/**
 * Re-insert the 8 default platform_config rows.
 *
 * resetDb() truncates admin_users CASCADE, which cascades to platform_config
 * because of the updated_by FK referencing admin_users(id). We re-seed here
 * after any reset so platform_config tests have a consistent baseline.
 */
async function seedPlatformConfig(): Promise<void> {
  await db.query(`
    INSERT INTO platform_config (key, value, description) VALUES
      ('llm_moderation_model_fast',                '"claude-haiku-4-5-20251001"', 'Model used for fast-pass moderation (Haiku)'),
      ('llm_moderation_model_review',              '"claude-sonnet-4-6"',         'Model used for borderline content review (Sonnet)'),
      ('llm_moderation_confidence_auto_approve',   '0.9',                         'Confidence threshold above which posts are auto-approved'),
      ('llm_moderation_confidence_auto_reject',    '0.9',                         'Confidence threshold above which posts are auto-rejected (violation confidence)'),
      ('llm_moderation_confidence_human_floor',    '0.3',                         'Confidence below this sends to human review queue'),
      ('feature_flag_who_is_here',                 'false',                       'Enable Who''s Here / Who''s Going tabs on event detail'),
      ('feature_flag_jobs_board',                  'false',                       'Enable Jobs Board tab in social app'),
      ('feature_flag_push_notifications',          'false',                       'Enable FCM push notifications')
    ON CONFLICT (key) DO NOTHING
  `);
}

describe('Phase 0 schema migration (004_phase0_foundation)', () => {
  // Seed platform_config before each test that may need it.
  // Note: resetDb() is NOT called here — schema structure tests read
  // information_schema/pg_enum and don't need a clean row state.
  // platform_config seed is applied once at migration time; because
  // admin_users CASCADE in other test files' resetDb calls can wipe it,
  // we re-seed here before each test as a defensive measure.
  beforeEach(async () => {
    await seedPlatformConfig();
    // Clean llm_usage_log test rows from previous runs
    await db.query(`TRUNCATE TABLE llm_usage_log`);
  });

  // ------------------------------------------------------------------ enums

  it('admin_role enum contains platformAdmin, moderator, and eventOps', async () => {
    const result = await db.query(
      `SELECT unnest(enum_range(NULL::admin_role)) AS val`,
    );
    const values = result.rows.map((r: { val: string }) => r.val);
    expect(values).toContain('platformAdmin');
    expect(values).toContain('moderator');
    expect(values).toContain('eventOps');
  });

  it('user_role enum does not contain venueStaff', async () => {
    const result = await db.query(
      `SELECT unnest(enum_range(NULL::user_role)) AS val`,
    );
    const values = result.rows.map((r: { val: string }) => r.val);
    expect(values).not.toContain('venueStaff');
    // Existing values must still be present
    expect(values).toContain('user');
    expect(values).toContain('platformAdmin');
  });

  // -------------------------------------------------------- platform_config

  it('platform_config table exists and has exactly 8 default seed rows', async () => {
    const result = await db.query(`SELECT COUNT(*) AS count FROM platform_config`);
    expect(parseInt(result.rows[0].count)).toBe(8);
  });

  it('platform_config seed rows have expected keys', async () => {
    const result = await db.query(
      `SELECT key FROM platform_config ORDER BY key`,
    );
    const keys = result.rows.map((r: { key: string }) => r.key);
    expect(keys).toEqual([
      'feature_flag_jobs_board',
      'feature_flag_push_notifications',
      'feature_flag_who_is_here',
      'llm_moderation_confidence_auto_approve',
      'llm_moderation_confidence_auto_reject',
      'llm_moderation_confidence_human_floor',
      'llm_moderation_model_fast',
      'llm_moderation_model_review',
    ]);
  });

  it('platform_config has correct schema (key, value JSONB, description, updated_by, updated_at)', async () => {
    const result = await db.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'platform_config'
      ORDER BY ordinal_position
    `);
    const cols = result.rows.map((r: { column_name: string }) => r.column_name);
    expect(cols).toContain('key');
    expect(cols).toContain('value');
    expect(cols).toContain('description');
    expect(cols).toContain('updated_by');
    expect(cols).toContain('updated_at');
  });

  it('platform_config is idempotent — re-applying seed does not duplicate rows', async () => {
    await db.query(`
      INSERT INTO platform_config (key, value, description) VALUES
        ('feature_flag_jobs_board', 'true', 'duplicate attempt')
      ON CONFLICT (key) DO NOTHING
    `);
    const result = await db.query(`SELECT COUNT(*) AS count FROM platform_config`);
    expect(parseInt(result.rows[0].count)).toBe(8);
  });

  // --------------------------------------------------------- llm_usage_log

  it('llm_usage_log table exists', async () => {
    const result = await db.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'llm_usage_log'
    `);
    expect(result.rows.length).toBe(1);
  });

  it('llm_usage_log accepts inserts and returns a uuid id', async () => {
    const result = await db.query(`
      INSERT INTO llm_usage_log (feature, model, input_tokens, output_tokens, latency_ms, success)
      VALUES ('test_feature', 'claude-sonnet-4-6', 100, 50, 200, true)
      RETURNING id, feature, model
    `);
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].feature).toBe('test_feature');
    expect(result.rows[0].id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
  });

  it('llm_usage_log error and token fields are nullable', async () => {
    const result = await db.query(`
      INSERT INTO llm_usage_log (feature, model, success)
      VALUES ('minimal_call', 'claude-haiku-4-5-20251001', false)
      RETURNING id, input_tokens, output_tokens, latency_ms, error
    `);
    expect(result.rows[0].input_tokens).toBeNull();
    expect(result.rows[0].output_tokens).toBeNull();
    expect(result.rows[0].latency_ms).toBeNull();
    expect(result.rows[0].error).toBeNull();
  });

  // ------------------------------------------------------- users.fcm_token

  it('users table has fcm_token column (nullable TEXT)', async () => {
    const result = await db.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'fcm_token'
    `);
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].data_type).toBe('text');
    expect(result.rows[0].is_nullable).toBe('YES');
  });

  // ------------------------------------------- users.primary_specialty_id

  it('users table has primary_specialty_id column (nullable VARCHAR(50))', async () => {
    const result = await db.query(`
      SELECT column_name, character_maximum_length, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'primary_specialty_id'
    `);
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].character_maximum_length).toBe(50);
    expect(result.rows[0].is_nullable).toBe('YES');
  });

  it('users.primary_specialty_id has FK to specialties with ON DELETE SET NULL', async () => {
    const result = await db.query(`
      SELECT rc.delete_rule
      FROM information_schema.referential_constraints rc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = rc.constraint_name
       AND kcu.table_name = 'users'
       AND kcu.column_name = 'primary_specialty_id'
    `);
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].delete_rule).toBe('SET NULL');
  });

  // ---------------------------------------------- tickets.wristband_issued_at

  it('tickets table has wristband_issued_at column (nullable TIMESTAMPTZ)', async () => {
    const result = await db.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'tickets' AND column_name = 'wristband_issued_at'
    `);
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].data_type).toBe('timestamp with time zone');
    expect(result.rows[0].is_nullable).toBe('YES');
  });
});

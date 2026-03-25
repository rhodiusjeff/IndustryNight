import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb, getTestPool } from './helpers/db';
import { resetFixtureCounters, createUser, createAdminUser } from './helpers/fixtures';
import { adminRefreshToken, adminToken, socialToken } from './helpers/auth';

const app = getApp();

beforeEach(async () => {
  await resetDb();
  resetFixtureCounters();
});

describe('Security Audit Logging', () => {
  it('logs validation_failed for bad phone format in request-code', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '5551234567' });

    expect(res.status).toBe(400);

    const pool = getTestPool();
    const auditRes = await pool.query(
      `SELECT action, entity_type, result, failure_reason, route, method, status_code
       FROM audit_log
       WHERE route = '/auth/request-code'
       ORDER BY occurred_at DESC
       LIMIT 1`
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      action: 'reject',
      entity_type: 'validation',
      result: 'failure',
      failure_reason: 'validation_failed',
      route: '/auth/request-code',
      method: 'POST',
      status_code: 400,
    });
  });

  it('logs verification_code_expired when verification code is expired', async () => {
    const phone = '+15555550191';  // Magic test prefix

    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone });

    expect(codeRes.status).toBe(200);

    const pool = getTestPool();
    await pool.query(
      `UPDATE verification_codes
       SET expires_at = NOW() - INTERVAL '1 minute'
       WHERE phone = $1`,
      [phone]
    );

    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone, code: codeRes.body.devCode });

    expect(verifyRes.status).toBe(400);

    const auditRes = await pool.query(
      `SELECT action, entity_type, result, failure_reason, route, method, status_code, metadata
       FROM audit_log
       WHERE route = '/auth/verify-code'
         AND result = 'failure'
       ORDER BY occurred_at DESC
       LIMIT 1`
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      action: 'login',
      entity_type: 'auth',
      result: 'failure',
      failure_reason: 'verification_code_expired',
      route: '/auth/verify-code',
      method: 'POST',
      status_code: 400,
    });
    expect(auditRes.rows[0].metadata).toMatchObject({ flow: 'verify_code' });
  });

  it('logs a single invalid_refresh_token event for rejected social refresh tokens', async () => {
    const user = await createUser();

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: adminRefreshToken(user.id) });

    expect(res.status).toBe(401);

    const pool = getTestPool();
    const auditRes = await pool.query(
      `SELECT action, entity_type, result, failure_reason, route, method, status_code, metadata
       FROM audit_log
       WHERE route = '/auth/refresh'
       ORDER BY occurred_at DESC`
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      action: 'login',
      entity_type: 'auth',
      result: 'failure',
      failure_reason: 'invalid_refresh_token',
      route: '/auth/refresh',
      method: 'POST',
      status_code: 401,
    });
    expect(auditRes.rows[0].metadata).toMatchObject({ flow: 'refresh' });
  });

  it('logs ban action for privileged admin user mutation', async () => {
    const adminUser = await createAdminUser();
    const targetUser = await createUser({ role: 'user' });

    const res = await request(app)
      .patch(`/admin/users/${targetUser.id}`)
      .set('Authorization', `Bearer ${adminToken(adminUser.id)}`)
      .send({ banned: true });

    expect(res.status).toBe(200);
    expect(res.body.user.banned).toBe(true);

    const pool = getTestPool();
    const auditRes = await pool.query(
      `SELECT action, entity_type, entity_id, actor_type, admin_actor_id, result, status_code, old_values, new_values
       FROM audit_log
       WHERE entity_type = 'user'
         AND entity_id = $1
         AND action = 'ban'
       ORDER BY occurred_at DESC
       LIMIT 1`,
      [targetUser.id]
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      action: 'ban',
      entity_type: 'user',
      entity_id: targetUser.id,
      actor_type: 'admin',
      admin_actor_id: adminUser.id,
      result: 'success',
      status_code: 200,
    });
    expect(auditRes.rows[0].old_values).toMatchObject({ banned: false });
    expect(auditRes.rows[0].new_values).toMatchObject({ banned: true });
  });

  it('logs connection create and delete audit events', async () => {
    const userA = await createUser();
    const userB = await createUser();

    const createRes = await request(app)
      .post('/connections')
      .set('Authorization', `Bearer ${socialToken(userA.id)}`)
      .send({ qrData: `industrynight://connect/${userB.id}` });

    expect(createRes.status).toBe(201);
    const connectionId = createRes.body.connection.id;

    const pool = getTestPool();
    const createAudit = await pool.query(
      `SELECT action, entity_type, entity_id, actor_type, actor_id, result, status_code
       FROM audit_log
       WHERE entity_type = 'connection'
         AND entity_id = $1
         AND action = 'create'
       ORDER BY occurred_at DESC
       LIMIT 1`,
      [connectionId]
    );

    expect(createAudit.rows).toHaveLength(1);
    expect(createAudit.rows[0]).toMatchObject({
      action: 'create',
      entity_type: 'connection',
      entity_id: connectionId,
      actor_type: 'user',
      actor_id: userA.id,
      result: 'success',
      status_code: 201,
    });

    const deleteRes = await request(app)
      .delete(`/connections/${connectionId}`)
      .set('Authorization', `Bearer ${socialToken(userA.id)}`);

    expect(deleteRes.status).toBe(204);

    const deleteAudit = await pool.query(
      `SELECT action, entity_type, entity_id, actor_type, actor_id, result, status_code, old_values
       FROM audit_log
       WHERE entity_type = 'connection'
         AND entity_id = $1
         AND action = 'delete'
       ORDER BY occurred_at DESC
       LIMIT 1`,
      [connectionId]
    );

    expect(deleteAudit.rows).toHaveLength(1);
    expect(deleteAudit.rows[0]).toMatchObject({
      action: 'delete',
      entity_type: 'connection',
      entity_id: connectionId,
      actor_type: 'user',
      actor_id: userA.id,
      result: 'success',
      status_code: 204,
    });
    expect(deleteAudit.rows[0].old_values).toMatchObject({
      userAId: expect.any(String),
      userBId: expect.any(String),
    });
  });
});

// ─── Migration 007 Regression Tests ──────────────────────────────────────────
//
// Validates the two bugs fixed in migration 007:
//
// Bug 1: DELETE FROM admin_users would 500 because the audit_log trigger
//        failed to promote actor_type → 'system' in the admin_actor_id cascade
//        path (migration 006 only NULLed admin_actor_id, leaving actor_type='admin',
//        which satisfies none of the ck_audit_log_actor_identity branches).
//
// Bug 2: A crafted UPDATE on audit_log that changed non-FK columns alongside
//        a FK-null could theoretically bypass the subset-column check in
//        migrations 005/006. Migration 007 hardens this with a full-row
//        NEW IS DISTINCT FROM OLD comparison.
// ─────────────────────────────────────────────────────────────────────────────
describe('Migration 007: audit_log immutability & admin cascade fix', () => {
  it('deleting an admin user promotes audit_log actor_type to system (bug 1 fix)', async () => {
    const pool = getTestPool();

    // Create an admin user and a social user to act as the entity.
    const admin = await createAdminUser();
    const user = await createUser();

    // Insert an audit_log row with actor_type='admin' and admin_actor_id set.
    const insertRes = await pool.query(
      `INSERT INTO audit_log
         (action, entity_type, entity_id, actor_type, admin_actor_id, result, request_id)
       VALUES ('update', 'user', $1, 'admin', $2, 'success', uuid_generate_v4())
       RETURNING id`,
      [user.id, admin.id]
    );
    const logId: string = insertRes.rows[0].id;

    // This DELETE should NOT throw — migration 007 ensures the cascade is
    // permitted and that actor_type is promoted to 'system'.
    await expect(
      pool.query(`DELETE FROM admin_users WHERE id = $1`, [admin.id])
    ).resolves.not.toThrow();

    // Verify the audit_log row was correctly tombstoned.
    const auditRes = await pool.query(
      `SELECT actor_type, actor_id, admin_actor_id FROM audit_log WHERE id = $1`,
      [logId]
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      actor_type: 'system',
      actor_id: null,
      admin_actor_id: null,
    });
  });

  it('deleting a social user promotes audit_log actor_type to system (existing user cascade path)', async () => {
    const pool = getTestPool();

    // Create a social user.
    const user = await createUser();

    // Insert an audit_log row with actor_type='user' and actor_id set.
    const insertRes = await pool.query(
      `INSERT INTO audit_log
         (action, entity_type, entity_id, actor_type, actor_id, result, request_id)
       VALUES ('update', 'user', $1, 'user', $1, 'success', uuid_generate_v4())
       RETURNING id`,
      [user.id]
    );
    const logId: string = insertRes.rows[0].id;

    // Manually delete the verification_code first (required by schema — phone PK).
    await pool.query(`DELETE FROM verification_codes WHERE phone = $1`, [user.phone]);

    // DELETE should not throw.
    await expect(
      pool.query(`DELETE FROM users WHERE id = $1`, [user.id])
    ).resolves.not.toThrow();

    // Verify tombstone.
    const auditRes = await pool.query(
      `SELECT actor_type, actor_id, admin_actor_id FROM audit_log WHERE id = $1`,
      [logId]
    );

    expect(auditRes.rows).toHaveLength(1);
    expect(auditRes.rows[0]).toMatchObject({
      actor_type: 'system',
      actor_id: null,
      admin_actor_id: null,
    });
  });

  it('rejects a direct UPDATE on audit_log that mutates non-FK columns alongside a FK null (bug 2 fix)', async () => {
    const pool = getTestPool();

    const admin = await createAdminUser();
    const user = await createUser();

    // Insert a baseline audit_log row.
    const insertRes = await pool.query(
      `INSERT INTO audit_log
         (action, entity_type, entity_id, actor_type, admin_actor_id, result, request_id)
       VALUES ('update', 'user', $1, 'admin', $2, 'success', gen_random_uuid())
       RETURNING id`,
      [user.id, admin.id]
    );
    const logId: string = insertRes.rows[0].id;

    // A crafted UPDATE that NULLs admin_actor_id (mimicking cascade) BUT also
    // changes metadata — should be rejected by the full-row comparison.
    await expect(
      pool.query(
        `UPDATE audit_log
           SET admin_actor_id = NULL,
               actor_type = 'system',
               metadata = '{"tampered": true}'
         WHERE id = $1`,
        [logId]
      )
    ).rejects.toThrow('audit_log is immutable');
  });
});

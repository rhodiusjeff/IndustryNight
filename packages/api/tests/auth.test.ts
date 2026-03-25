/**
 * Auth Flow Tests
 *
 * Tests the complete social authentication lifecycle:
 *   request-code -> verify-code -> token issued -> refresh -> me -> logout -> delete
 *
 * Uses magic test phone prefix (+1555555xxxx) which always routes to local
 * devCode verification (bypasses Twilio). This allows:
 *   - Automated tests to run without Twilio credentials
 *   - Dev environment to use real Twilio for manual testing with real phones
 *   - Magic prefix blocked in production for security
 *
 * Rate limiting is disabled in test mode (max: 0 = unlimited)
 * so tests can make unlimited requests without hitting 429.
 */
import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb, getTestPool } from './helpers/db';
import { socialToken, socialRefreshToken, adminRefreshToken, expiredToken } from './helpers/auth';
import { createAdminUser, createUser } from './helpers/fixtures';

const app = getApp();

beforeEach(async () => {
  await resetDb();
});

describe('POST /auth/request-code', () => {
  it('sends a verification code and returns devCode in dev mode', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550001' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Verification code sent');
    // Magic test prefix (+1555555xxxx) always returns devCode
    expect(res.body.devCode).toBeDefined();
    expect(res.body.devCode).toHaveLength(6);
  });

  it('stores the code in verification_codes table', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550001' });

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT code FROM verification_codes WHERE phone = $1',
      ['+15555550001']
    );

    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].code).toBe(res.body.devCode);
  });

  it('rejects invalid phone format', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '5551234567' }); // missing +1 prefix

    expect(res.status).toBe(400);
  });

  it('replaces existing code on repeat request', async () => {
    // First request
    const res1 = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550002' });

    // Second request (should overwrite via ON CONFLICT)
    const res2 = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550002' });

    expect(res1.body.devCode).not.toBe(res2.body.devCode);

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT code FROM verification_codes WHERE phone = $1',
      ['+15555550002']
    );
    expect(result.rows).toHaveLength(1); // Only one row, not two
    expect(result.rows[0].code).toBe(res2.body.devCode);
  });
});

describe('POST /auth/verify-code', () => {
  it('creates a new user on first verification', async () => {
    // Step 1: Request code
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550101' });

    // Step 2: Verify code
    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15555550101', code: codeRes.body.devCode });

    expect(verifyRes.status).toBe(200);
    expect(verifyRes.body.isNewUser).toBe(true);
    expect(verifyRes.body.accessToken).toBeDefined();
    expect(verifyRes.body.refreshToken).toBeDefined();
    expect(verifyRes.body.user).toBeDefined();
    expect(verifyRes.body.user.phone).toBe('+15555550101');
    expect(verifyRes.body.user.source).toBe('app');
  });

  it('returns existing user on subsequent verification', async () => {
    // Create user first
    await createUser({ phone: '+15555550102', name: 'Returning User' });

    // Request + verify code
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550102' });

    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15555550102', code: codeRes.body.devCode });

    expect(verifyRes.status).toBe(200);
    expect(verifyRes.body.isNewUser).toBe(false);
    expect(verifyRes.body.user.name).toBe('Returning User');
  });

  it('rejects wrong verification code', async () => {
    await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550103' });

    const res = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15555550103', code: '000000' });

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Invalid');
  });

  it('deletes the verification code after successful verification', async () => {
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550104' });

    await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15555550104', code: codeRes.body.devCode });

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT * FROM verification_codes WHERE phone = $1',
      ['+15555550104']
    );
    expect(result.rows).toHaveLength(0);
  });

  it('updates last_login_at timestamp', async () => {
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15555550105' });

    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15555550105', code: codeRes.body.devCode });

    expect(verifyRes.body.user.last_login_at).toBeDefined();
  });
});

describe('POST /auth/refresh', () => {
  it('issues new token pair with valid social refresh token', async () => {
    const user = await createUser();
    const refreshToken = socialRefreshToken(user.id);

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.user).toBeDefined();
    expect(res.body.user.id).toBe(user.id);
  });

  it('rejects admin refresh token on social refresh endpoint', async () => {
    const user = await createUser();
    const refreshToken = adminRefreshToken(user.id);

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid or expired refresh token' });
  });

  it('rejects access token used as refresh token', async () => {
    const user = await createUser();
    const accessToken = socialToken(user.id); // type: 'access', not 'refresh'

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: accessToken });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid or expired refresh token' });
  });

  it('returns 401 with explicit error for malformed refresh token', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: 'not-a-valid-token' });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid or expired refresh token' });
  });

  it('rejects refresh for banned user', async () => {
    const user = await createUser();

    // Ban the user directly in DB
    const pool = getTestPool();
    await pool.query('UPDATE users SET banned = true WHERE id = $1', [user.id]);

    const refreshToken = socialRefreshToken(user.id);
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });

    expect(res.status).toBe(401);
  });
});

describe('POST /admin/auth/refresh', () => {
  it('returns 401 with explicit error for malformed refresh token', async () => {
    const res = await request(app)
      .post('/admin/auth/refresh')
      .send({ refreshToken: 'not-a-valid-token' });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid or expired refresh token' });
  });

  it('returns 401 for social-family token sent to admin refresh endpoint', async () => {
    const user = await createUser({ role: 'platformAdmin' });
    const socialRefresh = socialRefreshToken(user.id, 'platformAdmin');

    const res = await request(app)
      .post('/admin/auth/refresh')
      .send({ refreshToken: socialRefresh });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: 'Invalid or expired refresh token' });
  });

  it('returns 200 for valid admin refresh token', async () => {
    const admin = await createAdminUser({ role: 'platformAdmin' });
    const adminRefresh = adminRefreshToken(admin.id, 'platformAdmin');

    const res = await request(app)
      .post('/admin/auth/refresh')
      .send({ refreshToken: adminRefresh });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
  });
});

describe('GET /auth/me', () => {
  it('returns current user with valid token', async () => {
    const user = await createUser({ name: 'Current User' });
    const token = socialToken(user.id);

    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(user.id);
    expect(res.body.user.name).toBe('Current User');
  });

  it('rejects request without token', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });

  it('rejects expired token', async () => {
    const user = await createUser();
    const token = expiredToken(user.id);

    // Small delay to ensure token is expired
    await new Promise((r) => setTimeout(r, 100));

    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });
});

describe('POST /auth/logout', () => {
  it('returns success with valid token', async () => {
    const user = await createUser();
    const token = socialToken(user.id);

    const res = await request(app)
      .post('/auth/logout')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Logged out');
  });
});

describe('DELETE /auth/me (account deletion)', () => {
  it('deletes user and all associated data', async () => {
    const user = await createUser({ phone: '+15559999010' });
    const token = socialToken(user.id);

    const res = await request(app)
      .delete('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Account deleted');

    // Verify user is gone
    const pool = getTestPool();
    const userResult = await pool.query('SELECT id FROM users WHERE id = $1', [user.id]);
    expect(userResult.rows).toHaveLength(0);
  });

  it('cleans up verification_codes before deleting user', async () => {
    const pool = getTestPool();

    const user = await createUser({ phone: '+15559999011' });

    // Create a verification code for this user's phone
    await pool.query(
      `INSERT INTO verification_codes (phone, code, expires_at)
       VALUES ($1, '123456', NOW() + INTERVAL '10 minutes')`,
      ['+15559999011']
    );

    const token = socialToken(user.id);
    await request(app)
      .delete('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    // Verify verification_codes is cleaned up
    const codeResult = await pool.query(
      'SELECT * FROM verification_codes WHERE phone = $1',
      ['+15559999011']
    );
    expect(codeResult.rows).toHaveLength(0);
  });

  it('cascades to posts, connections, tickets', async () => {
    const pool = getTestPool();

    const user = await createUser({ phone: '+15559999012' });
    const otherUser = await createUser({ phone: '+15559999013' });
    const event = await pool.query(
      `INSERT INTO events (name, venue_name, venue_address, start_time, end_time, activation_code, market_id)
       VALUES ($1, $2, $3, NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day 2 hours', $4, NULL)
       RETURNING id`,
      ['Cascade Event', 'Test Venue', '123 Test Ave', '1234']
    );

    // Create associated data
    await pool.query(
      `INSERT INTO posts (author_id, content, type) VALUES ($1, 'test post', 'general')`,
      [user.id]
    );
    await pool.query(
      `INSERT INTO connections (user_a_id, user_b_id) VALUES ($1, $2)`,
      [user.id, otherUser.id]
    );
    await pool.query(
      `INSERT INTO tickets (user_id, event_id, ticket_type, price, status, purchased_at)
       VALUES ($1, $2, 'General', 0, 'purchased', NOW())`,
      [user.id, event.rows[0].id]
    );

    const token = socialToken(user.id);
    await request(app)
      .delete('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    // All associated data should be cascaded away
    const posts = await pool.query('SELECT id FROM posts WHERE author_id = $1', [user.id]);
    const connections = await pool.query(
      'SELECT id FROM connections WHERE user_a_id = $1 OR user_b_id = $1',
      [user.id]
    );
    const tickets = await pool.query('SELECT id FROM tickets WHERE user_id = $1', [user.id]);

    expect(posts.rows).toHaveLength(0);
    expect(connections.rows).toHaveLength(0);
    expect(tickets.rows).toHaveLength(0);
  });
});

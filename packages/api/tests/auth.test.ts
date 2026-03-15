/**
 * Auth Flow Tests
 *
 * Tests the complete social authentication lifecycle:
 *   request-code -> verify-code -> token issued -> refresh -> me -> logout -> delete
 *
 * In test mode, Twilio is not configured, so the auth system uses
 * dev mode (stores codes in verification_codes table, returns devCode
 * in the response). This is the same path used during local development.
 *
 * Rate limiting is disabled in test mode (max: 0 = unlimited)
 * so tests can make unlimited requests without hitting 429.
 */
import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb, getTestPool } from './helpers/db';
import { socialToken, socialRefreshToken, adminRefreshToken, expiredToken } from './helpers/auth';
import { createUser } from './helpers/fixtures';

const app = getApp();

beforeEach(async () => {
  await resetDb();
});

describe('POST /auth/request-code', () => {
  it('sends a verification code and returns devCode in dev mode', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15551234567' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Verification code sent');
    // Dev mode returns the code for testing convenience
    expect(res.body.devCode).toBeDefined();
    expect(res.body.devCode).toHaveLength(6);
  });

  it('stores the code in verification_codes table', async () => {
    const res = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15551234567' });

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT code FROM verification_codes WHERE phone = $1',
      ['+15551234567']
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
      .send({ phone: '+15551234567' });

    // Second request (should overwrite via ON CONFLICT)
    const res2 = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15551234567' });

    expect(res1.body.devCode).not.toBe(res2.body.devCode);

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT code FROM verification_codes WHERE phone = $1',
      ['+15551234567']
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
      .send({ phone: '+15559999001' });

    // Step 2: Verify code
    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15559999001', code: codeRes.body.devCode });

    expect(verifyRes.status).toBe(200);
    expect(verifyRes.body.isNewUser).toBe(true);
    expect(verifyRes.body.accessToken).toBeDefined();
    expect(verifyRes.body.refreshToken).toBeDefined();
    expect(verifyRes.body.user).toBeDefined();
    expect(verifyRes.body.user.phone).toBe('+15559999001');
    expect(verifyRes.body.user.source).toBe('app');
  });

  it('returns existing user on subsequent verification', async () => {
    // Create user first
    await createUser({ phone: '+15559999002', name: 'Returning User' });

    // Request + verify code
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15559999002' });

    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15559999002', code: codeRes.body.devCode });

    expect(verifyRes.status).toBe(200);
    expect(verifyRes.body.isNewUser).toBe(false);
    expect(verifyRes.body.user.name).toBe('Returning User');
  });

  it('rejects wrong verification code', async () => {
    await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15559999003' });

    const res = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15559999003', code: '000000' });

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Invalid');
  });

  it('deletes the verification code after successful verification', async () => {
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15559999004' });

    await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15559999004', code: codeRes.body.devCode });

    const pool = getTestPool();
    const result = await pool.query(
      'SELECT * FROM verification_codes WHERE phone = $1',
      ['+15559999004']
    );
    expect(result.rows).toHaveLength(0);
  });

  it('updates last_login_at timestamp', async () => {
    const codeRes = await request(app)
      .post('/auth/request-code')
      .send({ phone: '+15559999005' });

    const verifyRes = await request(app)
      .post('/auth/verify-code')
      .send({ phone: '+15559999005', code: codeRes.body.devCode });

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
  });

  it('rejects access token used as refresh token', async () => {
    const user = await createUser();
    const accessToken = socialToken(user.id); // type: 'access', not 'refresh'

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: accessToken });

    expect(res.status).toBe(401);
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

    // Create associated data
    await pool.query(
      `INSERT INTO posts (author_id, content, type) VALUES ($1, 'test post', 'general')`,
      [user.id]
    );
    await pool.query(
      `INSERT INTO connections (user_a_id, user_b_id) VALUES ($1, $2)`,
      [user.id, otherUser.id]
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

    expect(posts.rows).toHaveLength(0);
    expect(connections.rows).toHaveLength(0);
  });
});

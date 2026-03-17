/**
 * Middleware Tests
 *
 * Tests the authentication and authorization middleware stack:
 *   - authenticate: requires valid social access token
 *   - authenticateAdmin: requires valid admin access token with tokenFamily='admin'
 *   - optionalAuth: adds user if token present, passes through if not
 *   - Token family separation: social tokens can't access admin routes and vice versa
 *
 * These tests hit real routes that use the middleware, not the
 * middleware functions directly. This tests the actual request pipeline.
 */
import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb } from './helpers/db';
import { socialToken, adminToken, generateToken } from './helpers/auth';
import { createUser, createAdminUser } from './helpers/fixtures';

const app = getApp();

beforeEach(async () => {
  await resetDb();
});

describe('Token Family Separation', () => {
  it('social token can access social routes (GET /auth/me)', async () => {
    const user = await createUser();
    const token = socialToken(user.id);

    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
  });

  it('admin token CANNOT access social auth routes (GET /auth/me)', async () => {
    const user = await createUser();
    const token = adminToken(user.id); // admin tokenFamily, but used on social route

    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    // authenticate now enforces tokenFamily === 'social'.
    expect(res.status).toBe(401);
  });

  it('social token CANNOT access admin routes (GET /admin/dashboard)', async () => {
    const user = await createUser({ role: 'platformAdmin' });
    const token = socialToken(user.id, 'platformAdmin');

    const res = await request(app)
      .get('/admin/dashboard')
      .set('Authorization', `Bearer ${token}`);

    // authenticateAdmin explicitly checks tokenFamily === 'admin'
    expect(res.status).toBe(401);
  });

  it('admin token CAN access admin routes (GET /admin/dashboard)', async () => {
    const user = await createUser({ role: 'platformAdmin' });
    const token = adminToken(user.id);

    const res = await request(app)
      .get('/admin/dashboard')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
  });
});

describe('Token Type Validation', () => {
  it('refresh token rejected on authenticated social routes', async () => {
    const user = await createUser();
    const token = generateToken({
      userId: user.id,
      type: 'refresh', // wrong type for an API call
      tokenFamily: 'social',
    });

    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });

  it('refresh token rejected on admin routes', async () => {
    const user = await createUser({ role: 'platformAdmin' });
    const token = generateToken({
      userId: user.id,
      type: 'refresh',
      tokenFamily: 'admin',
    });

    const res = await request(app)
      .get('/admin/dashboard')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });
});

describe('Missing / Malformed Auth Headers', () => {
  it('rejects request with no Authorization header', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });

  it('rejects request with empty Bearer token', async () => {
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', 'Bearer ');

    expect(res.status).toBe(401);
  });

  it('rejects request with non-Bearer auth scheme', async () => {
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', 'Basic dXNlcjpwYXNz');

    expect(res.status).toBe(401);
  });

  it('rejects request with garbage token', async () => {
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', 'Bearer not-a-real-jwt');

    expect(res.status).toBe(401);
  });
});

describe('Optional Auth (GET /posts)', () => {
  it('works without any token', async () => {
    const res = await request(app).get('/posts');

    expect(res.status).toBe(200);
    expect(res.body.posts).toBeDefined();
  });

  it('works with a valid token (adds user context)', async () => {
    const user = await createUser();
    const token = socialToken(user.id);

    const res = await request(app)
      .get('/posts')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.posts).toBeDefined();
  });

  it('works with an invalid token (ignores it, no error)', async () => {
    const res = await request(app)
      .get('/posts')
      .set('Authorization', 'Bearer invalid-jwt-token');

    // optionalAuth silently ignores bad tokens
    expect(res.status).toBe(200);
    expect(res.body.posts).toBeDefined();
  });
});

describe('Admin Auth (POST /admin/auth/login)', () => {
  it('returns admin tokens with valid credentials', async () => {
    await createAdminUser({
      email: 'admin@test.com',
      password: 'securepassword123',
    });

    const res = await request(app)
      .post('/admin/auth/login')
      .send({ email: 'admin@test.com', password: 'securepassword123' });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.admin).toBeDefined();
    expect(res.body.admin.email).toBe('admin@test.com');
  });

  it('rejects invalid password', async () => {
    await createAdminUser({
      email: 'admin2@test.com',
      password: 'correctpassword',
    });

    const res = await request(app)
      .post('/admin/auth/login')
      .send({ email: 'admin2@test.com', password: 'wrongpassword' });

    expect(res.status).toBe(401);
  });

  it('rejects non-existent email', async () => {
    const res = await request(app)
      .post('/admin/auth/login')
      .send({ email: 'nobody@test.com', password: 'anypassword' });

    expect(res.status).toBe(401);
  });
});

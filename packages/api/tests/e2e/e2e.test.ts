/**
 * E2E Tests — API against deployed infrastructure
 *
 * Runs against a real deployed API instance (dev or prod).
 * Uses magic test phone prefix (+1555555xxxx) for auth flows
 * so no real SMS is sent. Test user is created then deleted at the end.
 *
 * Usage:
 *   API_BASE_URL=https://dev-api.industrynight.net npm run test:e2e
 *
 * Notes:
 *   - Tests run in band (sequentially) so cleanup runs last
 *   - Each run generates a unique test phone to avoid collisions
 *   - Shared auth tokens are established once and reused
 *   - Read-only tests first, write tests last, cleanup at end
 */

import { api, authenticateTestPhone, type AuthTokens } from './client';
import { getBaseUrl, testPhone } from './config';

// Unique phone for this test run — prevents collision with parallel runs
const TEST_PHONE = testPhone();

// Shared auth state — populated once, reused across suites
let auth: AuthTokens;

// ─── Setup ──────────────────────────────────────────────────────────────────

beforeAll(async () => {
  console.log(`\nE2E target: ${getBaseUrl()}`);
  console.log(`Test phone:  ${TEST_PHONE}\n`);
});

// ─── Health & Public Endpoints ───────────────────────────────────────────────

describe('GET /health', () => {
  it('returns 200 with status ok', async () => {
    const res = await api.get<{ status: string; timestamp: string }>('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
    expect(new Date(res.body.timestamp).getTime()).not.toBeNaN();
  });
});

describe('GET /specialties', () => {
  it('returns 200 with a specialties array', async () => {
    const res = await api.get<{ specialties: unknown[] }>('/specialties');
    expect(res.status).toBe(200);
    expect(Array.isArray((res.body as any).specialties)).toBe(true);
  });
});

// ─── Auth Flow ────────────────────────────────────────────────────────────────

describe('Auth flow (magic prefix)', () => {
  it('request-code returns devCode for magic prefix phone', async () => {
    const res = await api.post<{ message: string; devCode?: string }>(
      '/auth/request-code',
      { phone: TEST_PHONE }
    );
    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Verification code sent');
    expect(res.body.devCode).toBeDefined();
    expect(res.body.devCode).toHaveLength(6);
  });

  it('verify-code creates new user and returns tokens', async () => {
    // Re-request to get fresh code (previous test consumed its own)
    auth = await authenticateTestPhone(TEST_PHONE);

    expect(auth.accessToken).toBeDefined();
    expect(auth.refreshToken).toBeDefined();
    expect(auth.user).toBeDefined();
    expect((auth.user as any).phone).toBe(TEST_PHONE);
    expect(auth.isNewUser).toBe(true);
  });

  it('verify-code with wrong code returns 400', async () => {
    // Request a code (won't use it)
    await api.post('/auth/request-code', { phone: TEST_PHONE });

    const res = await api.post<{ message: string }>('/auth/verify-code', {
      phone: TEST_PHONE,
      code: '000000',
    });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/invalid/i);
  });

  it('re-authenticate returns existing user (isNewUser = false)', async () => {
    // Re-authenticate the same test phone
    const tokens = await authenticateTestPhone(TEST_PHONE);
    expect(tokens.isNewUser).toBe(false);
    expect((tokens.user as any).phone).toBe(TEST_PHONE);
    // Update shared auth tokens
    auth = tokens;
  });
});

// ─── GET /auth/me ─────────────────────────────────────────────────────────────

describe('GET /auth/me', () => {
  it('returns current user with valid token', async () => {
    const res = await api.get<{ user: { id: string; phone: string } }>('/auth/me', auth.accessToken);
    expect(res.status).toBe(200);
    expect((res.body as any).user.phone).toBe(TEST_PHONE);
    expect((res.body as any).user.id).toBeDefined();
  });

  it('returns 401 without token', async () => {
    const res = await api.get('/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns 401 with garbage token', async () => {
    const res = await api.get('/auth/me', 'not.a.real.token');
    expect(res.status).toBe(401);
  });
});

// ─── Token Refresh ────────────────────────────────────────────────────────────

describe('POST /auth/refresh', () => {
  it('issues new tokens with valid refresh token', async () => {
    const res = await api.post<AuthTokens>('/auth/refresh', {
      refreshToken: auth.refreshToken,
    });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    // Update for subsequent tests
    auth = res.body;
  });

  it('returns 401 with explicit error for invalid refresh token', async () => {
    const res = await api.post<{ error: string }>('/auth/refresh', {
      refreshToken: 'invalid.refresh.token',
    });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid|expired/i);
  });

  it('rejects access token used as refresh token', async () => {
    const res = await api.post<{ error: string }>('/auth/refresh', {
      refreshToken: auth.accessToken,
    });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid|expired/i);
  });
});

// ─── Auth-gated Social Endpoints ─────────────────────────────────────────────

describe('GET /events', () => {
  it('returns 401 without auth token', async () => {
    const res = await api.get('/events');
    expect(res.status).toBe(401);
  });

  it('returns 200 with valid auth token', async () => {
    const res = await api.get<{ events: unknown[] }>('/events', auth.accessToken);
    expect(res.status).toBe(200);
    expect(Array.isArray((res.body as any).events)).toBe(true);
  });
});

describe('GET /posts', () => {
  it('returns 200 without auth', async () => {
    const res = await api.get<unknown>('/posts');
    expect(res.status).toBe(200);
  });

  it('returns 200 with auth', async () => {
    const res = await api.get<unknown>('/posts', auth.accessToken);
    expect(res.status).toBe(200);
  });
});

describe('GET /sponsors', () => {
  it('returns 401 without auth token', async () => {
    const res = await api.get('/sponsors');
    expect(res.status).toBe(401);
  });

  it('returns 200 with valid auth token', async () => {
    const res = await api.get<{ sponsors: unknown[] }>('/sponsors', auth.accessToken);
    expect(res.status).toBe(200);
    expect(Array.isArray((res.body as any).sponsors)).toBe(true);
  });
});

describe('GET /discounts', () => {
  it('returns 401 without auth token', async () => {
    const res = await api.get('/discounts');
    expect(res.status).toBe(401);
  });

  it('returns 200 with valid auth token', async () => {
    const res = await api.get<{ discounts: unknown[] }>('/discounts', auth.accessToken);
    expect(res.status).toBe(200);
    expect(Array.isArray((res.body as any).discounts)).toBe(true);
  });
});

// ─── Admin Endpoint Auth Guard ────────────────────────────────────────────────

describe('Admin route token family guard', () => {
  it('rejects social token on admin dashboard', async () => {
    const res = await api.get('/admin/dashboard', auth.accessToken);
    expect(res.status).toBe(401);
  });

  it('rejects social refresh token on admin refresh', async () => {
    const res = await api.post<{ error: string }>('/admin/auth/refresh', {
      refreshToken: auth.refreshToken,
    });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid|expired/i);
  });
});

// ─── POST /auth/logout ────────────────────────────────────────────────────────

describe('POST /auth/logout', () => {
  it('returns 200 with valid token', async () => {
    const res = await api.post('/auth/logout', {}, auth.accessToken);
    expect(res.status).toBe(200);
  });
});

// ─── Cleanup — run last ───────────────────────────────────────────────────────

describe('Cleanup: delete test user', () => {
  it('deletes the test user account via DELETE /auth/me', async () => {
    // Re-authenticate (we just logged out)
    auth = await authenticateTestPhone(TEST_PHONE);

    const res = await api.delete('/auth/me', auth.accessToken);
    expect(res.status).toBe(200);
  });

  it('confirms test user no longer exists', async () => {
    // Re-authenticate from scratch. If the user was truly deleted,
    // the API will auto-create a new account and return isNewUser=true.
    const reAuth = await authenticateTestPhone(TEST_PHONE);
    expect(reAuth.isNewUser).toBe(true);

    // Clean up the re-created test account so the environment stays pristine.
    const del = await api.delete('/auth/me', reAuth.accessToken);
    expect(del.status).toBe(200);
  });
});

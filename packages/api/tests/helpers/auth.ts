/**
 * Auth Test Helpers
 *
 * Generates real JWTs for test requests. These use the same signing
 * logic as production (jsonwebtoken + the test JWT_SECRET) so they
 * are verified identically by the auth middleware.
 *
 * Usage:
 *   import { socialToken, adminToken } from './helpers/auth';
 *
 *   it('requires auth', async () => {
 *     await request(app)
 *       .get('/auth/me')
 *       .set('Authorization', `Bearer ${socialToken(userId)}`)
 *       .expect(200);
 *   });
 */
import jwt from 'jsonwebtoken';

// Must match the JWT_SECRET set in test environment variables
const TEST_JWT_SECRET = 'test-jwt-secret-that-is-at-least-32-chars-long';

interface TokenOptions {
  userId: string;
  role?: string;
  type?: 'access' | 'refresh';
  tokenFamily?: 'social' | 'admin';
  expiresIn?: string;
}

/** Generate a signed JWT with full control over claims */
export function generateToken(options: TokenOptions): string {
  const {
    userId,
    role = 'user',
    type = 'access',
    tokenFamily = 'social',
    expiresIn = '15m',
  } = options;

  return jwt.sign(
    { userId, role, type, tokenFamily },
    TEST_JWT_SECRET,
    { expiresIn } as jwt.SignOptions
  );
}

/** Shorthand: social app access token (most common in tests) */
export function socialToken(userId: string, role = 'user'): string {
  return generateToken({ userId, role, tokenFamily: 'social' });
}

/** Shorthand: social app refresh token */
export function socialRefreshToken(userId: string, role = 'user'): string {
  return generateToken({ userId, role, type: 'refresh', tokenFamily: 'social' });
}

/** Shorthand: admin app access token */
export function adminToken(userId: string, role = 'platformAdmin'): string {
  return generateToken({ userId, role, tokenFamily: 'admin' });
}

/** Shorthand: admin app refresh token */
export function adminRefreshToken(userId: string, role = 'platformAdmin'): string {
  return generateToken({ userId, role, type: 'refresh', tokenFamily: 'admin' });
}

/** Generate an expired token (for testing token expiry handling) */
export function expiredToken(userId: string): string {
  return generateToken({ userId, expiresIn: '0s' });
}

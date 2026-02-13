import { Router } from 'express';
import { z } from 'zod';
import { validate, phoneSchema } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import { generateTokenPair, verifyToken } from '../config/auth';
import { query, queryOne } from '../config/database';
import { sendVerificationCode } from '../services/sms';
import { generateVerificationCode } from '../utils/jwt';
import { BadRequestError, UnauthorizedError } from '../utils/errors';

const router = Router();

// Request verification code
const requestCodeSchema = z.object({
  body: z.object({
    phone: phoneSchema,
  }),
});

router.post('/request-code', validate(requestCodeSchema), async (req, res, next): Promise<void> => {
  try {
    const { phone } = req.body;

    // Check if user exists
    const user = await queryOne<{ id: string }>('SELECT id FROM users WHERE phone = $1', [phone]);

    if (!user) {
      res.status(404).json({ message: 'User not found' });
      return;
    }

    // Generate and store code
    const code = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await query(
      `INSERT INTO verification_codes (phone, code, expires_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (phone) DO UPDATE SET code = $2, expires_at = $3`,
      [phone, code, expiresAt]
    );

    // Send SMS
    await sendVerificationCode(phone, code);

    res.json({ message: 'Verification code sent' });
  } catch (error) {
    next(error);
  }
});

// Verify code
const verifyCodeSchema = z.object({
  body: z.object({
    phone: phoneSchema,
    code: z.string().length(6),
  }),
});

router.post('/verify-code', validate(verifyCodeSchema), async (req, res, next) => {
  try {
    const { phone, code } = req.body;

    // Check code
    const storedCode = await queryOne<{ code: string; expires_at: Date }>(
      'SELECT code, expires_at FROM verification_codes WHERE phone = $1',
      [phone]
    );

    if (!storedCode || storedCode.code !== code) {
      throw new BadRequestError('Invalid verification code');
    }

    if (new Date() > storedCode.expires_at) {
      throw new BadRequestError('Verification code expired');
    }

    // Delete used code
    await query('DELETE FROM verification_codes WHERE phone = $1', [phone]);

    // Get user
    const user = await queryOne<{ id: string; role: string }>(
      'SELECT id, role FROM users WHERE phone = $1',
      [phone]
    );

    if (!user) {
      throw new BadRequestError('User not found');
    }

    // Update last login
    await query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user.id]);

    // Generate tokens
    const tokens = generateTokenPair(user.id, user.role);

    // Get full user
    const fullUser = await queryOne(
      'SELECT * FROM users WHERE id = $1',
      [user.id]
    );

    res.json({
      ...tokens,
      user: fullUser,
    });
  } catch (error) {
    next(error);
  }
});

// Refresh token
const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string(),
  }),
});

router.post('/refresh', validate(refreshSchema), async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    const payload = verifyToken(refreshToken);
    if (payload.type !== 'refresh') {
      throw new UnauthorizedError('Invalid token type');
    }

    const user = await queryOne<{ id: string; role: string; banned: boolean }>(
      'SELECT id, role, banned FROM users WHERE id = $1',
      [payload.userId]
    );

    if (!user || user.banned) {
      throw new UnauthorizedError('User not found or banned');
    }

    const tokens = generateTokenPair(user.id, user.role);
    const fullUser = await queryOne('SELECT * FROM users WHERE id = $1', [user.id]);

    res.json({
      ...tokens,
      user: fullUser,
    });
  } catch (error) {
    next(error);
  }
});

// Logout (client-side token deletion, but could add to blacklist)
router.post('/logout', authenticate, async (_req, res) => {
  res.json({ message: 'Logged out' });
});

// Get current user
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.user!.userId]);
    res.json({ user });
  } catch (error) {
    next(error);
  }
});

export default router;

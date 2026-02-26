import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { validate } from '../middleware/validation';
import { authenticateAdmin } from '../middleware/admin-auth';
import { verifyToken, generateAdminTokenPair } from '../config/auth';
import { queryOne } from '../config/database';
import { UnauthorizedError } from '../utils/errors';

const router = Router();

// Login
const loginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
});

router.post('/login', validate(loginSchema), async (req, res, next): Promise<void> => {
  try {
    const { email, password } = req.body;

    const admin = await queryOne<{
      id: string;
      email: string;
      password_hash: string;
      name: string;
      role: string;
      is_active: boolean;
      created_at: Date;
      last_login_at: Date | null;
    }>('SELECT * FROM admin_users WHERE email = $1', [email.toLowerCase()]);

    if (!admin || !admin.is_active) {
      throw new UnauthorizedError('Invalid credentials');
    }

    const validPassword = await bcrypt.compare(password, admin.password_hash);
    if (!validPassword) {
      throw new UnauthorizedError('Invalid credentials');
    }

    // Update last login
    await queryOne(
      'UPDATE admin_users SET last_login_at = NOW() WHERE id = $1',
      [admin.id]
    );

    const tokens = generateAdminTokenPair(admin.id, admin.role);

    res.json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      admin: {
        id: admin.id,
        email: admin.email,
        name: admin.name,
        role: admin.role,
        isActive: admin.is_active,
        createdAt: admin.created_at,
        lastLoginAt: new Date(),
      },
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

router.post('/refresh', validate(refreshSchema), async (req, res, next): Promise<void> => {
  try {
    const { refreshToken } = req.body;

    const payload = verifyToken(refreshToken);

    if (payload.type !== 'refresh' || payload.tokenFamily !== 'admin') {
      throw new UnauthorizedError('Invalid refresh token');
    }

    const admin = await queryOne<{
      id: string;
      email: string;
      name: string;
      role: string;
      is_active: boolean;
      created_at: Date;
      last_login_at: Date | null;
    }>('SELECT * FROM admin_users WHERE id = $1', [payload.userId]);

    if (!admin || !admin.is_active) {
      throw new UnauthorizedError('Invalid refresh token');
    }

    const tokens = generateAdminTokenPair(admin.id, admin.role);

    res.json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      admin: {
        id: admin.id,
        email: admin.email,
        name: admin.name,
        role: admin.role,
        isActive: admin.is_active,
        createdAt: admin.created_at,
        lastLoginAt: admin.last_login_at,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Get current admin
router.get('/me', authenticateAdmin, async (req, res, next): Promise<void> => {
  try {
    const admin = await queryOne<{
      id: string;
      email: string;
      name: string;
      role: string;
      is_active: boolean;
      created_at: Date;
      last_login_at: Date | null;
    }>('SELECT id, email, name, role, is_active, created_at, last_login_at FROM admin_users WHERE id = $1', [req.user!.userId]);

    if (!admin) {
      throw new UnauthorizedError('Admin not found');
    }

    res.json({
      admin: {
        id: admin.id,
        email: admin.email,
        name: admin.name,
        role: admin.role,
        isActive: admin.is_active,
        createdAt: admin.created_at,
        lastLoginAt: admin.last_login_at,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Logout
router.post('/logout', authenticateAdmin, (_req, res) => {
  res.json({ message: 'Logged out' });
});

export default router;

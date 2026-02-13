import { Router } from 'express';
import { z } from 'zod';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import { query, queryOne } from '../config/database';
import { generateQrData } from '../utils/jwt';
import { NotFoundError } from '../utils/errors';

const router = Router();

// Search users
const searchSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    q: z.string().optional(),
    specialties: z.string().optional(),
  }),
});

router.get('/', authenticate, validate(searchSchema), async (req, res, next) => {
  try {
    const { q, specialties, limit = 20, offset = 0 } = req.query as unknown as {
      q?: string;
      specialties?: string;
      limit: number;
      offset: number;
    };

    let whereClause = 'WHERE banned = false AND profile_completed = true';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (q) {
      whereClause += ` AND (name ILIKE $${paramIndex} OR bio ILIKE $${paramIndex})`;
      params.push(`%${q}%`);
      paramIndex++;
    }

    if (specialties) {
      const specialtyList = specialties.split(',');
      whereClause += ` AND specialties && $${paramIndex}::text[]`;
      params.push(specialtyList);
      paramIndex++;
    }

    params.push(limit, offset);

    const users = await query(
      `SELECT id, name, bio, profile_photo_url, specialties, verification_status
       FROM users ${whereClause}
       ORDER BY created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ users });
  } catch (error) {
    next(error);
  }
});

// Get user by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const user = await queryOne(
      `SELECT id, name, bio, profile_photo_url, specialties, social_links,
              verification_status, created_at
       FROM users WHERE id = $1 AND banned = false`,
      [req.params.id]
    );

    if (!user) {
      throw new NotFoundError('User not found');
    }

    res.json({ user });
  } catch (error) {
    next(error);
  }
});

// Update profile
const updateProfileSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(50).optional(),
    email: z.string().email().optional(),
    bio: z.string().max(500).optional(),
    specialties: z.array(z.string()).optional(),
    socialLinks: z.object({
      instagram: z.string().optional(),
      tiktok: z.string().optional(),
      linkedin: z.string().optional(),
      website: z.string().url().optional(),
    }).optional(),
  }),
});

router.patch('/me', authenticate, validate(updateProfileSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, email, bio, specialties, socialLinks } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name !== undefined) {
      updates.push(`name = $${paramIndex++}`);
      params.push(name);
    }
    if (email !== undefined) {
      updates.push(`email = $${paramIndex++}`);
      params.push(email);
    }
    if (bio !== undefined) {
      updates.push(`bio = $${paramIndex++}`);
      params.push(bio);
    }
    if (specialties !== undefined) {
      updates.push(`specialties = $${paramIndex++}`);
      params.push(specialties);
    }
    if (socialLinks !== undefined) {
      updates.push(`social_links = $${paramIndex++}`);
      params.push(JSON.stringify(socialLinks));
    }

    if (updates.length === 0) {
      const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.user!.userId]);
      res.json({ user });
      return;
    }

    // Check if profile is now complete
    updates.push(`profile_completed = (name IS NOT NULL AND array_length(specialties, 1) > 0)`);
    updates.push(`updated_at = NOW()`);

    params.push(req.user!.userId);

    const user = await queryOne(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    res.json({ user });
  } catch (error) {
    next(error);
  }
});

// Get QR code data
router.get('/me/qr', authenticate, async (req, res) => {
  const qrData = generateQrData(req.user!.userId);
  res.json({ qrData });
});

export default router;

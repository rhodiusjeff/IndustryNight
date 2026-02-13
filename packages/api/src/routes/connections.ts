import { Router } from 'express';
import { z } from 'zod';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import { query, queryOne } from '../config/database';
import { parseQrData } from '../utils/jwt';
import { NotFoundError, BadRequestError, ConflictError } from '../utils/errors';

const router = Router();

// List connections for current user
router.get('/', authenticate, validate(paginationSchema), async (req, res, next) => {
  try {
    const { limit = 20, offset = 0 } = req.query as unknown as { limit: number; offset: number };
    const userId = req.user!.userId;

    const connections = await query(
      `SELECT c.*,
              ua.id as user_a_id, ua.name as user_a_name, ua.profile_photo_url as user_a_photo, ua.specialties as user_a_specialties,
              ub.id as user_b_id, ub.name as user_b_name, ub.profile_photo_url as user_b_photo, ub.specialties as user_b_specialties
       FROM connections c
       JOIN users ua ON c.user_a_id = ua.id
       JOIN users ub ON c.user_b_id = ub.id
       WHERE c.user_a_id = $1 OR c.user_b_id = $1
       ORDER BY c.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    res.json({ connections });
  } catch (error) {
    next(error);
  }
});

// Create connection from QR code scan (instant connection)
const createConnectionSchema = z.object({
  body: z.object({
    qrData: z.string(),
    eventId: z.string().uuid().optional(),
  }),
});

router.post('/', authenticate, validate(createConnectionSchema), async (req, res, next) => {
  try {
    const { qrData, eventId } = req.body;
    const currentUserId = req.user!.userId;

    const otherUserId = parseQrData(qrData);
    if (!otherUserId) {
      throw new BadRequestError('Invalid QR code');
    }

    if (otherUserId === currentUserId) {
      throw new BadRequestError('Cannot connect with yourself');
    }

    // Check if other user exists and is not banned
    const otherUser = await queryOne<{ id: string }>(
      'SELECT id FROM users WHERE id = $1 AND banned = false',
      [otherUserId]
    );

    if (!otherUser) {
      throw new NotFoundError('User not found');
    }

    // Check for existing connection (using canonical ordering)
    const userAId = currentUserId < otherUserId ? currentUserId : otherUserId;
    const userBId = currentUserId < otherUserId ? otherUserId : currentUserId;

    const existing = await queryOne(
      `SELECT id FROM connections WHERE user_a_id = $1 AND user_b_id = $2`,
      [userAId, userBId]
    );

    if (existing) {
      throw new ConflictError('Connection already exists');
    }

    // Create connection (instant - no pending state)
    const connection = await queryOne(
      `INSERT INTO connections (user_a_id, user_b_id, event_id)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [userAId, userBId, eventId || null]
    );

    // TODO: Log to audit_log

    res.status(201).json({ connection });
  } catch (error) {
    next(error);
  }
});

// Delete connection
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const userId = req.user!.userId;

    const connection = await queryOne<{ id: string; user_a_id: string; user_b_id: string }>(
      'SELECT id, user_a_id, user_b_id FROM connections WHERE id = $1',
      [req.params.id]
    );

    if (!connection) {
      throw new NotFoundError('Connection not found');
    }

    // Either user can delete the connection
    if (connection.user_a_id !== userId && connection.user_b_id !== userId) {
      throw new BadRequestError('Not authorized to remove this connection');
    }

    // TODO: Log to audit_log before deletion (capture old_values)

    await query('DELETE FROM connections WHERE id = $1', [req.params.id]);

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

export default router;

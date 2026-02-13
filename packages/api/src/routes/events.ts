import { Router } from 'express';
import { z } from 'zod';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import { query, queryOne } from '../config/database';
import { NotFoundError, BadRequestError } from '../utils/errors';

const router = Router();

// List events
const listEventsSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    status: z.enum(['draft', 'published', 'cancelled', 'completed']).optional(),
    upcoming: z.coerce.boolean().optional(),
  }),
});

router.get('/', authenticate, validate(listEventsSchema), async (req, res, next) => {
  try {
    const { status, upcoming, limit = 20, offset = 0 } = req.query as unknown as {
      status?: string;
      upcoming?: boolean;
      limit: number;
      offset: number;
    };

    let whereClause = 'WHERE 1=1';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (status) {
      whereClause += ` AND status = $${paramIndex++}`;
      params.push(status);
    }

    if (upcoming) {
      whereClause += ` AND start_time > NOW()`;
    }

    params.push(limit, offset);

    const events = await query(
      `SELECT * FROM events ${whereClause}
       ORDER BY start_time ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ events });
  } catch (error) {
    next(error);
  }
});

// Get event by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const event = await queryOne('SELECT * FROM events WHERE id = $1', [req.params.id]);

    if (!event) {
      throw new NotFoundError('Event not found');
    }

    res.json({ event });
  } catch (error) {
    next(error);
  }
});

// Get user's tickets for an event
router.get('/:id/tickets', authenticate, async (req, res, next) => {
  try {
    const tickets = await query(
      'SELECT * FROM tickets WHERE event_id = $1 AND user_id = $2',
      [req.params.id, req.user!.userId]
    );

    res.json({ tickets });
  } catch (error) {
    next(error);
  }
});

// Check in to event
const checkinSchema = z.object({
  body: z.object({
    activationCode: z.string().min(1),
  }),
});

router.post('/:id/checkin', authenticate, validate(checkinSchema), async (req, res, next) => {
  try {
    const { activationCode } = req.body;
    const eventId = req.params.id;
    const userId = req.user!.userId;

    // Verify event and code
    const event = await queryOne<{ id: string; activation_code: string; status: string }>(
      'SELECT id, activation_code, status FROM events WHERE id = $1',
      [eventId]
    );

    if (!event) {
      throw new NotFoundError('Event not found');
    }

    if (event.status !== 'published') {
      throw new BadRequestError('Event is not active');
    }

    if (event.activation_code !== activationCode.toUpperCase()) {
      throw new BadRequestError('Invalid activation code');
    }

    // Check for existing ticket
    let ticket = await queryOne<{ id: string; status: string }>(
      'SELECT id, status FROM tickets WHERE event_id = $1 AND user_id = $2',
      [eventId, userId]
    );

    if (ticket) {
      if (ticket.status === 'checkedIn') {
        throw new BadRequestError('Already checked in');
      }

      // Update existing ticket
      ticket = await queryOne(
        `UPDATE tickets SET status = 'checkedIn', checked_in_at = NOW()
         WHERE id = $1 RETURNING *`,
        [ticket.id]
      );
    } else {
      // Create walk-in ticket
      ticket = await queryOne(
        `INSERT INTO tickets (user_id, event_id, ticket_type, price, status, checked_in_at, purchased_at)
         VALUES ($1, $2, 'walk-in', 0, 'checkedIn', NOW(), NOW())
         RETURNING *`,
        [userId, eventId]
      );
    }

    // Update event attendee count
    await query(
      'UPDATE events SET attendee_count = attendee_count + 1 WHERE id = $1',
      [eventId]
    );

    res.json({ ticket });
  } catch (error) {
    next(error);
  }
});

export default router;

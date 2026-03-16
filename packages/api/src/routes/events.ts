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
      whereClause += ` AND start_time > NOW() - INTERVAL '24 hours'`;
    }

    params.push(limit, offset);

    const events = await query(
      `SELECT
         e.*,
         (SELECT url FROM event_images WHERE event_id = e.id ORDER BY sort_order ASC LIMIT 1) AS hero_image_url,
         (SELECT COUNT(*)::int FROM event_images WHERE event_id = e.id) AS image_count,
         (SELECT COUNT(*)::int FROM customer_products WHERE event_id = e.id AND status = 'active') AS partner_count
       FROM events e
       ${whereClause}
       ORDER BY e.start_time ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ events });
  } catch (error) {
    next(error);
  }
});

// Get current user's active tickets across all events (powers events list sorting + Connect tab)
router.get('/my-tickets', authenticate, async (req, res, next) => {
  try {
    const tickets = await query(
      `SELECT t.*, t.price::float AS price,
              e.name AS event_name, e.start_time AS event_start_time,
              e.end_time AS event_end_time, e.venue_name AS event_venue_name
       FROM tickets t
       JOIN events e ON e.id = t.event_id
       WHERE t.user_id = $1 AND t.status IN ('purchased', 'checkedIn')
       ORDER BY e.start_time ASC`,
      [req.user!.userId]
    );

    res.json({ tickets });
  } catch (error) {
    next(error);
  }
});

// Get event by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const event = await queryOne(
      `SELECT
         e.*,
         COALESCE(
           (SELECT json_agg(ei ORDER BY ei.sort_order)
            FROM event_images ei WHERE ei.event_id = e.id),
           '[]'::json
         ) AS images,
         COALESCE(
           (SELECT json_agg(json_build_object(
             'id', cp.id, 'customer_id', c.id, 'name', c.name, 'logo_url', c.logo_url,
             'product_type', p.product_type,
             'tier', p.config->>'tier', 'vendor_category', p.config->>'category'
           ))
            FROM customer_products cp
            JOIN customers c ON c.id = cp.customer_id
            JOIN products p ON p.id = cp.product_id
            WHERE cp.event_id = e.id AND cp.status = 'active'),
           '[]'::json
         ) AS partners
       FROM events e
       WHERE e.id = $1`,
      [req.params.id]
    );

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
      'SELECT *, price::float AS price FROM tickets WHERE event_id = $1 AND user_id = $2',
      [req.params.id, req.user!.userId]
    );

    res.json({ tickets });
  } catch (error) {
    next(error);
  }
});

// Get current user's valid ticket for an event
router.get('/:id/my-ticket', authenticate, async (req, res, next) => {
  try {
    const ticket = await queryOne(
      `SELECT *, price::float AS price FROM tickets
       WHERE event_id = $1 AND user_id = $2 AND status NOT IN ('cancelled', 'refunded')
       ORDER BY CASE WHEN status = 'checkedIn' THEN 0 ELSE 1 END, created_at DESC
       LIMIT 1`,
      [req.params.id, req.user!.userId]
    );

    if (!ticket) {
      throw new NotFoundError('No ticket found');
    }

    res.json({ ticket });
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
         WHERE id = $1 RETURNING *, price::float AS price`,
        [ticket.id]
      );
    } else {
      throw new BadRequestError('No ticket found. You need a ticket to check in to this event.');
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

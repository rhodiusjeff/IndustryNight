import { Router } from 'express';
import { z } from 'zod';
import multer from 'multer';
import sharp from 'sharp';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticateAdmin } from '../middleware/admin-auth';
import { query, queryOne } from '../config/database';
import { generateActivationCode } from '../utils/jwt';
import { NotFoundError, BadRequestError } from '../utils/errors';
import { uploadImage, deleteImage } from '../services/storage';

const router = Router();

// All admin routes require admin authentication
router.use(authenticateAdmin);

// Multer: memory storage, any image type, 20MB max (sharp normalises on the way out)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new BadRequestError('Only image files are allowed'));
    }
  },
});

// ================================================================
// DASHBOARD
// ================================================================

router.get('/dashboard', async (_req, res, next) => {
  try {
    const stats = await queryOne<{
      total_users: number;
      verified_users: number;
      total_events: number;
      upcoming_events: number;
      total_connections: number;
      total_posts: number;
    }>(`
      SELECT
        (SELECT COUNT(*) FROM users WHERE banned = false)::int as total_users,
        (SELECT COUNT(*) FROM users WHERE verification_status = 'verified')::int as verified_users,
        (SELECT COUNT(*) FROM events)::int as total_events,
        (SELECT COUNT(*) FROM events WHERE start_time > NOW() AND status = 'published')::int as upcoming_events,
        (SELECT COUNT(*) FROM connections)::int as total_connections,
        (SELECT COUNT(*) FROM posts WHERE is_hidden = false)::int as total_posts
    `);

    res.json({ stats });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// USERS
// ================================================================

const listUsersSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    q: z.string().optional(),
    role: z.string().optional(),
    verificationStatus: z.string().optional(),
  }),
});

router.get('/users', validate(listUsersSchema), async (req, res, next) => {
  try {
    const { q, role, verificationStatus, limit, offset } = req.query as any;

    let whereClause = 'WHERE 1=1';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (q) {
      whereClause += ` AND (name ILIKE $${paramIndex} OR phone ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`;
      params.push(`%${q}%`);
      paramIndex++;
    }
    if (role) {
      whereClause += ` AND role = $${paramIndex++}`;
      params.push(role);
    }
    if (verificationStatus) {
      whereClause += ` AND verification_status = $${paramIndex++}`;
      params.push(verificationStatus);
    }

    params.push(limit, offset);

    const users = await query(
      `SELECT * FROM users ${whereClause}
       ORDER BY created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ users });
  } catch (error) {
    next(error);
  }
});

const updateUserSchema = z.object({
  body: z.object({
    role: z.enum(['user', 'venueStaff', 'platformAdmin']).optional(),
    banned: z.boolean().optional(),
    verificationStatus: z.enum(['unverified', 'pending', 'verified', 'rejected']).optional(),
  }),
});

router.patch('/users/:id', validate(updateUserSchema), async (req, res, next): Promise<void> => {
  try {
    const { role, banned, verificationStatus } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (role !== undefined) { updates.push(`role = $${paramIndex++}`); params.push(role); }
    if (banned !== undefined) { updates.push(`banned = $${paramIndex++}`); params.push(banned); }
    if (verificationStatus !== undefined) {
      updates.push(`verification_status = $${paramIndex++}`);
      params.push(verificationStatus);
    }

    if (updates.length === 0) {
      const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.params.id]);
      res.json({ user });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.id);

    const user = await queryOne(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    if (!user) throw new NotFoundError('User not found');

    res.json({ user });
  } catch (error) {
    next(error);
  }
});

const addUserSchema = z.object({
  body: z.object({
    phone: z.string(),
    name: z.string().optional(),
    email: z.string().email().optional(),
    role: z.enum(['user', 'venueStaff', 'platformAdmin']).default('user'),
  }),
});

router.post('/users', validate(addUserSchema), async (req, res, next) => {
  try {
    const { phone, name, email, role } = req.body;

    const user = await queryOne(
      `INSERT INTO users (phone, name, email, role, source)
       VALUES ($1, $2, $3, $4, 'admin')
       RETURNING *`,
      [phone, name, email, role]
    );

    res.status(201).json({ user });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — List
// ================================================================

const listEventsSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    status: z.enum(['draft', 'published', 'cancelled', 'completed']).optional(),
  }),
});

router.get('/events', validate(listEventsSchema), async (req, res, next) => {
  try {
    const { status, limit, offset } = req.query as any;

    const params: unknown[] = [];
    let whereClause = '';
    let paramIndex = 1;

    if (status) {
      whereClause = `WHERE e.status = $${paramIndex++}`;
      params.push(status);
    }

    params.push(limit, offset);

    const events = await query(
      `SELECT
         e.*,
         (SELECT url FROM event_images WHERE event_id = e.id ORDER BY sort_order ASC LIMIT 1) AS hero_image_url,
         (SELECT COUNT(*)::int FROM event_images WHERE event_id = e.id) AS image_count,
         (SELECT COUNT(*)::int FROM event_sponsors WHERE event_id = e.id) AS sponsor_count
       FROM events e
       ${whereClause}
       ORDER BY e.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ events });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Get single (with images + sponsors)
// ================================================================

router.get('/events/:id', async (req, res, next) => {
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
             'id', s.id, 'name', s.name, 'tier', s.tier, 'logo_url', s.logo_url
           ))
            FROM event_sponsors es
            JOIN sponsors s ON s.id = es.sponsor_id
            WHERE es.event_id = e.id),
           '[]'::json
         ) AS sponsors,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id) AS ticket_count,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id AND status = 'purchased') AS tickets_purchased,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id AND status = 'checkedIn') AS tickets_checked_in
       FROM events e
       WHERE e.id = $1`,
      [req.params.id]
    );

    if (!event) throw new NotFoundError('Event not found');

    res.json({ event });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Create
// ================================================================

const createEventSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    venueName: z.string().optional(),
    venueAddress: z.string().optional(),
    startTime: z.string().datetime(),
    endTime: z.string().datetime(),
    description: z.string().optional(),
    capacity: z.number().positive().optional(),
    poshEventId: z.string().optional(),
  }),
});

router.post('/events', validate(createEventSchema), async (req, res, next) => {
  try {
    const { name, venueName, venueAddress, startTime, endTime, description, capacity, poshEventId } = req.body;
    const activationCode = generateActivationCode();

    const event = await queryOne(
      `INSERT INTO events
         (name, venue_name, venue_address, start_time, end_time, description, capacity, activation_code, posh_event_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [name, venueName ?? null, venueAddress ?? null, startTime, endTime, description ?? null, capacity ?? null, activationCode, poshEventId ?? null]
    );

    res.status(201).json({ event });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Update (with publish gate)
// ================================================================

const updateEventSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    description: z.string().nullable().optional(),
    venueName: z.string().min(1).optional(),
    venueAddress: z.string().nullable().optional(),
    startTime: z.string().datetime().optional(),
    endTime: z.string().datetime().optional(),
    poshEventId: z.string().nullable().optional(),
    status: z.enum(['draft', 'published', 'cancelled', 'completed']).optional(),
    capacity: z.number().positive().nullable().optional(),
  }),
});

router.patch('/events/:id', validate(updateEventSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, venueName, venueAddress, startTime, endTime, poshEventId, status, capacity } = req.body;

    // Publish gate: verify all requirements before allowing status → published
    if (status === 'published') {
      const check = await queryOne<{
        posh_event_id: string | null;
        venue_name: string | null;
        image_count: number;
      }>(
        `SELECT
           e.posh_event_id,
           e.venue_name,
           (SELECT COUNT(*)::int FROM event_images WHERE event_id = e.id) AS image_count
         FROM events e WHERE e.id = $1`,
        [req.params.id]
      );

      if (!check) throw new NotFoundError('Event not found');

      // Use incoming values if being set in this same request
      const effectivePoshId  = poshEventId  !== undefined ? poshEventId  : check.posh_event_id;
      const effectiveVenueName = venueName  !== undefined ? venueName    : check.venue_name;

      if (!effectivePoshId)   throw new BadRequestError('Cannot publish: Posh event ID is required');
      if (!effectiveVenueName) throw new BadRequestError('Cannot publish: Venue name is required');
      if (check.image_count === 0) throw new BadRequestError('Cannot publish: At least one image is required');
    }

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name        !== undefined) { updates.push(`name = $${paramIndex++}`);         params.push(name); }
    if (description !== undefined) { updates.push(`description = $${paramIndex++}`);  params.push(description); }
    if (venueName   !== undefined) { updates.push(`venue_name = $${paramIndex++}`);   params.push(venueName); }
    if (venueAddress !== undefined){ updates.push(`venue_address = $${paramIndex++}`);params.push(venueAddress); }
    if (startTime   !== undefined) { updates.push(`start_time = $${paramIndex++}`);   params.push(startTime); }
    if (endTime     !== undefined) { updates.push(`end_time = $${paramIndex++}`);     params.push(endTime); }
    if (poshEventId !== undefined) { updates.push(`posh_event_id = $${paramIndex++}`);params.push(poshEventId); }
    if (status      !== undefined) { updates.push(`status = $${paramIndex++}`);       params.push(status); }
    if (capacity    !== undefined) { updates.push(`capacity = $${paramIndex++}`);     params.push(capacity); }

    if (updates.length === 0) {
      const event = await queryOne('SELECT * FROM events WHERE id = $1', [req.params.id]);
      res.json({ event });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.id);

    const event = await queryOne(
      `UPDATE events SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    if (!event) throw new NotFoundError('Event not found');

    res.json({ event });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Delete (draft only)
// ================================================================

router.delete('/events/:id', async (req, res, next): Promise<void> => {
  try {
    const rows = await query('SELECT status FROM events WHERE id = $1', [req.params.id]);
    if (rows.length === 0) throw new NotFoundError('Event not found');
    if ((rows[0] as any).status !== 'draft') {
      throw new BadRequestError('Only draft events can be deleted');
    }
    await query('DELETE FROM events WHERE id = $1', [req.params.id]);
    res.json({ message: 'Event deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Images
// ================================================================

const MAX_IMAGES_PER_EVENT = 5;

router.post('/events/:id/images', upload.single('image'), async (req, res, next): Promise<void> => {
  try {
    if (!req.file) {
      throw new BadRequestError('No image file provided');
    }

    // Enforce max images per event
    const countResult = await queryOne<{ count: number }>(
      'SELECT COUNT(*)::int AS count FROM event_images WHERE event_id = $1',
      [req.params.id]
    );
    if ((countResult?.count ?? 0) >= MAX_IMAGES_PER_EVENT) {
      throw new BadRequestError(`Events may have at most ${MAX_IMAGES_PER_EVENT} images`);
    }

    // Verify event exists
    const eventExists = await queryOne<{ id: string }>(
      'SELECT id FROM events WHERE id = $1',
      [req.params.id]
    );
    if (!eventExists) throw new NotFoundError('Event not found');

    // Determine sort_order (append to end)
    const sortResult = await queryOne<{ max_order: number | null }>(
      'SELECT MAX(sort_order) AS max_order FROM event_images WHERE event_id = $1',
      [req.params.id]
    );
    const sortOrder = (sortResult?.max_order ?? -1) + 1;

    // Normalise: resize to max 800px wide, convert to JPEG 80%
    const processed = await sharp(req.file.buffer)
      .resize({ width: 800, withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();

    const url = await uploadImage(processed, 'image.jpg', `events/${req.params.id}`);

    const image = await queryOne(
      `INSERT INTO event_images (event_id, url, sort_order)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [req.params.id, url, sortOrder]
    );

    res.status(201).json({ image });
  } catch (error) {
    next(error);
  }
});

router.patch('/events/:id/images/:imageId/hero', async (req, res, next): Promise<void> => {
  try {
    const image = await queryOne<{ id: string; event_id: string; sort_order: number }>(
      'SELECT id, event_id, sort_order FROM event_images WHERE id = $1',
      [req.params.imageId]
    );
    if (!image) throw new NotFoundError('Image not found');
    if (image.event_id !== req.params.id) throw new NotFoundError('Image not found');

    if (image.sort_order !== 0) {
      // Swap: current hero gets this image's sort_order, this image gets 0
      await query(
        `UPDATE event_images SET sort_order = $1 WHERE event_id = $2 AND sort_order = 0`,
        [image.sort_order, req.params.id]
      );
      await query(
        `UPDATE event_images SET sort_order = 0 WHERE id = $1`,
        [req.params.imageId]
      );
    }

    res.json({ message: 'Hero image updated' });
  } catch (error) {
    next(error);
  }
});

router.delete('/events/:id/images/:imageId', async (req, res, next): Promise<void> => {
  try {
    const image = await queryOne<{ id: string; url: string; event_id: string; sort_order: number }>(
      'SELECT id, url, event_id, sort_order FROM event_images WHERE id = $1',
      [req.params.imageId]
    );

    if (!image) throw new NotFoundError('Image not found');
    if (image.event_id !== req.params.id) throw new NotFoundError('Image not found');

    await deleteImage(image.url);
    await query('DELETE FROM event_images WHERE id = $1', [req.params.imageId]);

    // If we deleted the hero, promote the next image
    if (image.sort_order === 0) {
      const next = await queryOne<{ id: string }>(
        'SELECT id FROM event_images WHERE event_id = $1 ORDER BY sort_order ASC LIMIT 1',
        [req.params.id]
      );
      if (next) {
        await query('UPDATE event_images SET sort_order = 0 WHERE id = $1', [next.id]);
      }
    }

    res.json({ message: 'Image deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// EVENTS — Sponsor associations
// ================================================================

router.post('/events/:id/sponsors', async (req, res, next): Promise<void> => {
  try {
    const { sponsorId } = req.body;

    if (!sponsorId) throw new BadRequestError('sponsorId is required');

    // Verify event and sponsor both exist
    const [event, sponsor] = await Promise.all([
      queryOne('SELECT id FROM events WHERE id = $1', [req.params.id]),
      queryOne('SELECT id FROM sponsors WHERE id = $1', [sponsorId]),
    ]);

    if (!event)   throw new NotFoundError('Event not found');
    if (!sponsor) throw new NotFoundError('Sponsor not found');

    await query(
      `INSERT INTO event_sponsors (event_id, sponsor_id)
       VALUES ($1, $2)
       ON CONFLICT (event_id, sponsor_id) DO NOTHING`,
      [req.params.id, sponsorId]
    );

    res.status(201).json({ message: 'Sponsor added to event' });
  } catch (error) {
    next(error);
  }
});

router.delete('/events/:id/sponsors/:sponsorId', async (req, res, next): Promise<void> => {
  try {
    const result = await query(
      'DELETE FROM event_sponsors WHERE event_id = $1 AND sponsor_id = $2',
      [req.params.id, req.params.sponsorId]
    );

    // pg's query result has rowCount
    if ((result as any).rowCount === 0) throw new NotFoundError('Association not found');

    res.json({ message: 'Sponsor removed from event' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// TICKETS — global ticket list (all events)
// ================================================================

const listAllTicketsSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    status: z.enum(['purchased', 'checkedIn', 'cancelled', 'refunded']).optional(),
    eventId: z.string().uuid().optional(),
    userId: z.string().uuid().optional(),
    q: z.string().optional(),
  }),
});

router.get('/tickets', validate(listAllTicketsSchema), async (req, res, next) => {
  try {
    const { status, eventId, userId, q, limit = 50, offset = 0 } = req.query as unknown as {
      status?: string;
      eventId?: string;
      userId?: string;
      q?: string;
      limit: number;
      offset: number;
    };

    let whereClause = 'WHERE 1=1';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (status) {
      whereClause += ` AND t.status = $${paramIndex++}`;
      params.push(status);
    }

    if (eventId) {
      whereClause += ` AND t.event_id = $${paramIndex++}`;
      params.push(eventId);
    }

    if (userId) {
      whereClause += ` AND t.user_id = $${paramIndex++}`;
      params.push(userId);
    }

    if (q) {
      whereClause += ` AND (u.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex})`;
      paramIndex++;
      params.push(`%${q}%`);
    }

    params.push(limit, offset);

    const tickets = await query(
      `SELECT t.*, t.price::float AS price,
              u.name AS user_name, u.phone AS user_phone,
              e.name AS event_name
       FROM tickets t
       JOIN users u ON u.id = t.user_id
       JOIN events e ON e.id = t.event_id
       ${whereClause}
       ORDER BY t.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ tickets });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// TICKETS — per-event ticket management
// ================================================================

const listEventTicketsSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    status: z.enum(['purchased', 'checkedIn', 'cancelled', 'refunded']).optional(),
  }),
});

router.get('/events/:id/tickets', validate(listEventTicketsSchema), async (req, res, next) => {
  try {
    const { status, limit = 50, offset = 0 } = req.query as unknown as {
      status?: string;
      limit: number;
      offset: number;
    };

    let whereClause = 'WHERE t.event_id = $1';
    const params: unknown[] = [req.params.id];
    let paramIndex = 2;

    if (status) {
      whereClause += ` AND t.status = $${paramIndex++}`;
      params.push(status);
    }

    params.push(limit, offset);

    const tickets = await query(
      `SELECT t.*, t.price::float AS price, u.name AS user_name, u.phone AS user_phone
       FROM tickets t
       JOIN users u ON u.id = t.user_id
       ${whereClause}
       ORDER BY t.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ tickets });
  } catch (error) {
    next(error);
  }
});

const issueTicketSchema = z.object({
  body: z.object({
    userId: z.string().uuid(),
    ticketType: z.string().default('admin'),
    price: z.number().min(0).default(0),
  }),
});

router.post('/events/:id/tickets', validate(issueTicketSchema), async (req, res, next) => {
  try {
    const { userId, ticketType, price } = req.body;
    const eventId = req.params.id;

    // Verify event exists
    const event = await queryOne('SELECT id FROM events WHERE id = $1', [eventId]);
    if (!event) throw new NotFoundError('Event not found');

    // Verify user exists
    const user = await queryOne('SELECT id FROM users WHERE id = $1', [userId]);
    if (!user) throw new NotFoundError('User not found');

    // Check for duplicate (non-cancelled/refunded ticket for same user+event)
    const existing = await queryOne(
      `SELECT id FROM tickets
       WHERE event_id = $1 AND user_id = $2 AND status NOT IN ('cancelled', 'refunded')`,
      [eventId, userId]
    );
    if (existing) {
      throw new BadRequestError('User already has an active ticket for this event');
    }

    // Issue the ticket
    const ticket = await queryOne<{ id: string }>(
      `INSERT INTO tickets (user_id, event_id, ticket_type, price, status, purchased_at)
       VALUES ($1, $2, $3, $4, 'purchased', NOW())
       RETURNING *`,
      [userId, eventId, ticketType, price]
    );

    // Return with user info (cast price to float for JSON number)
    const enriched = await queryOne(
      `SELECT t.*, t.price::float AS price, u.name AS user_name, u.phone AS user_phone
       FROM tickets t
       JOIN users u ON u.id = t.user_id
       WHERE t.id = $1`,
      [ticket!.id]
    );

    res.status(201).json({ ticket: enriched });
  } catch (error) {
    next(error);
  }
});

router.delete('/events/:id/tickets/:ticketId', async (req, res, next): Promise<void> => {
  try {
    const ticket = await queryOne<{ id: string; status: string; event_id: string }>(
      'SELECT id, status, event_id FROM tickets WHERE id = $1 AND event_id = $2',
      [req.params.ticketId, req.params.id]
    );

    if (!ticket) throw new NotFoundError('Ticket not found');

    // If checked in, decrement attendee count
    if (ticket.status === 'checkedIn') {
      await query(
        'UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0) WHERE id = $1',
        [ticket.event_id]
      );
    }

    await query('DELETE FROM tickets WHERE id = $1', [ticket.id]);

    res.json({ message: 'Ticket deleted' });
  } catch (error) {
    next(error);
  }
});

router.patch('/events/:id/tickets/:ticketId/refund', async (req, res, next) => {
  try {
    const ticket = await queryOne<{ id: string; status: string; event_id: string }>(
      'SELECT id, status, event_id FROM tickets WHERE id = $1 AND event_id = $2',
      [req.params.ticketId, req.params.id]
    );

    if (!ticket) throw new NotFoundError('Ticket not found');

    if (ticket.status === 'cancelled' || ticket.status === 'refunded') {
      throw new BadRequestError(`Ticket is already ${ticket.status}`);
    }

    // If checked in, decrement attendee count
    if (ticket.status === 'checkedIn') {
      await query(
        'UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0) WHERE id = $1',
        [ticket.event_id]
      );
    }

    const updated = await queryOne<{ id: string }>(
      `UPDATE tickets SET status = 'refunded'
       WHERE id = $1 RETURNING *`,
      [ticket.id]
    );

    // Return with user info (cast price to float for JSON number)
    const enriched = await queryOne(
      `SELECT t.*, t.price::float AS price, u.name AS user_name, u.phone AS user_phone
       FROM tickets t
       JOIN users u ON u.id = t.user_id
       WHERE t.id = $1`,
      [updated!.id]
    );

    res.json({
      ticket: enriched,
      message: 'Ticket marked as refunded (no payment refund processed)',
    });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// IMAGE CATALOG — all event images across all events
// ================================================================

const listImagesSchema = paginationSchema;

router.get('/images', validate(listImagesSchema), async (req, res, next) => {
  try {
    const { limit, offset } = req.query as any;

    const images = await query(
      `SELECT
         ei.id,
         ei.event_id,
         ei.url,
         ei.sort_order,
         ei.uploaded_at,
         e.name AS event_name
       FROM event_images ei
       JOIN events e ON e.id = ei.event_id
       ORDER BY ei.uploaded_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json({ images });
  } catch (error) {
    next(error);
  }
});

router.delete('/images/:imageId', async (req, res, next): Promise<void> => {
  try {
    const image = await queryOne<{ id: string; url: string }>(
      'SELECT id, url FROM event_images WHERE id = $1',
      [req.params.imageId]
    );

    if (!image) throw new NotFoundError('Image not found');

    await deleteImage(image.url);
    await query('DELETE FROM event_images WHERE id = $1', [req.params.imageId]);

    res.json({ message: 'Image deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// SPONSORS
// ================================================================

router.get('/sponsors', async (_req, res, next) => {
  try {
    const sponsors = await query('SELECT * FROM sponsors ORDER BY tier DESC, name ASC');
    res.json({ sponsors });
  } catch (error) {
    next(error);
  }
});

router.post('/sponsors', async (req, res, next) => {
  try {
    const { name, description, website, tier } = req.body;
    const sponsor = await queryOne(
      `INSERT INTO sponsors (name, description, website, tier)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [name, description, website, tier || 'bronze']
    );
    res.status(201).json({ sponsor });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// VENDORS
// ================================================================

router.get('/vendors', async (_req, res, next) => {
  try {
    const vendors = await query('SELECT * FROM vendors ORDER BY name ASC');
    res.json({ vendors });
  } catch (error) {
    next(error);
  }
});

router.post('/vendors', async (req, res, next) => {
  try {
    const { name, description, website, contactEmail, category } = req.body;
    const vendor = await queryOne(
      `INSERT INTO vendors (name, description, website, contact_email, category)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [name, description, website, contactEmail, category || 'other']
    );
    res.status(201).json({ vendor });
  } catch (error) {
    next(error);
  }
});

export default router;

import { Router } from 'express';
import { z } from 'zod';
import multer from 'multer';
import sharp from 'sharp';
import { validate, paginationSchema, phoneSchema } from '../middleware/validation';
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
// MARKETS
// ================================================================

// GET /admin/markets — list all markets with event counts
router.get('/markets', async (_req, res, next) => {
  try {
    const markets = await query(
      `SELECT m.*,
              (SELECT COUNT(*) FROM events WHERE market_id = m.id)::int as event_count
       FROM markets m
       ORDER BY m.sort_order ASC, m.name ASC`
    );
    res.json({ markets });
  } catch (error) {
    next(error);
  }
});

const createMarketSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(100),
    description: z.string().max(1000).optional(),
    timezone: z.string().max(50).optional(),
    sortOrder: z.number().int().default(0),
  }),
});

// POST /admin/markets — create market (slug auto-generated from name)
router.post('/markets', validate(createMarketSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, timezone, sortOrder } = req.body;

    // Auto-generate slug from name
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim();

    if (!slug) {
      res.status(400).json({ error: 'Name must contain at least one alphanumeric character' });
      return;
    }

    // Check uniqueness
    const existing = await queryOne(
      'SELECT id FROM markets WHERE name = $1 OR slug = $2',
      [name, slug]
    );
    if (existing) {
      res.status(409).json({ error: 'A market with this name already exists' });
      return;
    }

    const market = await queryOne(
      `INSERT INTO markets (name, slug, description, timezone, sort_order)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [name, slug, description || null, timezone || null, sortOrder]
    );

    res.status(201).json({ market });
  } catch (error) {
    next(error);
  }
});

const updateMarketSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(100).optional(),
    description: z.string().max(1000).nullable().optional(),
    timezone: z.string().max(50).nullable().optional(),
    isActive: z.boolean().optional(),
    sortOrder: z.number().int().optional(),
  }),
});

// PATCH /admin/markets/:id — update market (slug NOT editable)
router.patch('/markets/:id', validate(updateMarketSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, timezone, isActive, sortOrder } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name !== undefined) {
      // Check name uniqueness (excluding self)
      const existing = await queryOne(
        'SELECT id FROM markets WHERE name = $1 AND id != $2',
        [name, req.params.id]
      );
      if (existing) {
        res.status(409).json({ error: 'A market with this name already exists' });
        return;
      }
      updates.push(`name = $${paramIndex++}`);
      params.push(name);
    }
    if (description !== undefined) { updates.push(`description = $${paramIndex++}`); params.push(description); }
    if (timezone !== undefined) { updates.push(`timezone = $${paramIndex++}`); params.push(timezone); }
    if (isActive !== undefined) { updates.push(`is_active = $${paramIndex++}`); params.push(isActive); }
    if (sortOrder !== undefined) { updates.push(`sort_order = $${paramIndex++}`); params.push(sortOrder); }

    if (updates.length === 0) {
      const market = await queryOne('SELECT * FROM markets WHERE id = $1', [req.params.id]);
      if (!market) { res.status(404).json({ error: 'Market not found' }); return; }
      res.json({ market });
      return;
    }

    params.push(req.params.id);
    const market = await queryOne(
      `UPDATE markets SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    if (!market) {
      res.status(404).json({ error: 'Market not found' });
      return;
    }

    res.json({ market });
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
    phone: phoneSchema,
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
         m.name AS market_name,
         (SELECT url FROM event_images WHERE event_id = e.id ORDER BY sort_order ASC LIMIT 1) AS hero_image_url,
         (SELECT COUNT(*)::int FROM event_images WHERE event_id = e.id) AS image_count,
         (SELECT COUNT(*)::int FROM customer_products WHERE event_id = e.id AND status = 'active') AS partner_count
       FROM events e
       LEFT JOIN markets m ON m.id = e.market_id
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
         m.name AS market_name,
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
         ) AS partners,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id) AS ticket_count,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id AND status = 'purchased') AS tickets_purchased,
         (SELECT COUNT(*)::int FROM tickets WHERE event_id = e.id AND status = 'checkedIn') AS tickets_checked_in
       FROM events e
       LEFT JOIN markets m ON m.id = e.market_id
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
    startTime: z.string().min(1),
    endTime: z.string().min(1),
    description: z.string().optional(),
    capacity: z.number().positive().optional(),
    poshEventId: z.string().optional(),
    marketId: z.string().uuid().optional(),
  }),
});

router.post('/events', validate(createEventSchema), async (req, res, next) => {
  try {
    const { name, venueName, venueAddress, startTime, endTime, description, capacity, poshEventId, marketId } = req.body;
    const activationCode = generateActivationCode();

    const row = await queryOne(
      `INSERT INTO events
         (name, venue_name, venue_address, start_time, end_time, description, capacity, activation_code, posh_event_id, market_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [name, venueName ?? null, venueAddress ?? null, startTime, endTime, description ?? null, capacity ?? null, activationCode, poshEventId ?? null, marketId ?? null]
    );

    // Join market name for the response
    const event = marketId
      ? await queryOne(
          `SELECT e.*, m.name AS market_name FROM events e LEFT JOIN markets m ON m.id = e.market_id WHERE e.id = $1`,
          [(row as any).id]
        )
      : row;

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
    startTime: z.string().min(1).optional(),
    endTime: z.string().min(1).optional(),
    poshEventId: z.string().nullable().optional(),
    status: z.enum(['draft', 'published', 'cancelled', 'completed']).optional(),
    capacity: z.number().positive().nullable().optional(),
    marketId: z.string().uuid().nullable().optional(),
  }),
});

router.patch('/events/:id', validate(updateEventSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, venueName, venueAddress, startTime, endTime, poshEventId, status, capacity, marketId } = req.body;

    // Publish gate: verify all requirements before allowing status → published
    if (status === 'published') {
      const check = await queryOne<{
        posh_event_id: string | null;
        venue_name: string | null;
        venue_address: string | null;
        market_id: string | null;
        image_count: number;
      }>(
        `SELECT
           e.posh_event_id,
           e.venue_name,
           e.venue_address,
           e.market_id,
           (SELECT COUNT(*)::int FROM event_images WHERE event_id = e.id) AS image_count
         FROM events e WHERE e.id = $1`,
        [req.params.id]
      );

      if (!check) throw new NotFoundError('Event not found');

      // Use incoming values if being set in this same request
      const effectivePoshId      = poshEventId  !== undefined ? poshEventId  : check.posh_event_id;
      const effectiveVenueName   = venueName    !== undefined ? venueName    : check.venue_name;
      const effectiveVenueAddr   = venueAddress !== undefined ? venueAddress : check.venue_address;
      const effectiveMarketId    = marketId     !== undefined ? marketId     : check.market_id;

      if (!effectivePoshId)      throw new BadRequestError('Cannot publish: Posh event ID is required');
      if (!effectiveVenueName)   throw new BadRequestError('Cannot publish: Venue name is required');
      if (!effectiveVenueAddr)   throw new BadRequestError('Cannot publish: Venue address is required');
      if (!effectiveMarketId)    throw new BadRequestError('Cannot publish: Market must be assigned');
      if (check.image_count === 0) throw new BadRequestError('Cannot publish: At least one image is required');
    }

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name         !== undefined) { updates.push(`name = $${paramIndex++}`);          params.push(name); }
    if (description  !== undefined) { updates.push(`description = $${paramIndex++}`);   params.push(description); }
    if (venueName    !== undefined) { updates.push(`venue_name = $${paramIndex++}`);    params.push(venueName); }
    if (venueAddress !== undefined) { updates.push(`venue_address = $${paramIndex++}`); params.push(venueAddress); }
    if (startTime    !== undefined) { updates.push(`start_time = $${paramIndex++}`);    params.push(startTime); }
    if (endTime      !== undefined) { updates.push(`end_time = $${paramIndex++}`);      params.push(endTime); }
    if (poshEventId  !== undefined) { updates.push(`posh_event_id = $${paramIndex++}`); params.push(poshEventId); }
    if (status       !== undefined) { updates.push(`status = $${paramIndex++}`);        params.push(status); }
    if (capacity     !== undefined) { updates.push(`capacity = $${paramIndex++}`);      params.push(capacity); }
    if (marketId     !== undefined) { updates.push(`market_id = $${paramIndex++}`);     params.push(marketId); }

    if (updates.length === 0) {
      const event = await queryOne(
        'SELECT e.*, m.name AS market_name FROM events e LEFT JOIN markets m ON m.id = e.market_id WHERE e.id = $1',
        [req.params.id]
      );
      res.json({ event });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.id);

    await queryOne(
      `UPDATE events SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    // Re-fetch with market join for consistent response
    const event = await queryOne(
      'SELECT e.*, m.name AS market_name FROM events e LEFT JOIN markets m ON m.id = e.market_id WHERE e.id = $1',
      [req.params.id]
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
// EVENTS — Partner associations (sponsors + vendors via customer_products)
// ================================================================

const addEventPartnerSchema = z.object({
  body: z.object({
    customerId: z.string().uuid(),
    productId: z.string().uuid(),
    pricePaidCents: z.number().int().min(0).optional(),
    notes: z.string().optional(),
  }),
});

router.post('/events/:id/partners', validate(addEventPartnerSchema), async (req, res, next): Promise<void> => {
  try {
    const { customerId, productId, pricePaidCents, notes } = req.body;

    // Verify event, customer, and product all exist
    const [event, customer, product] = await Promise.all([
      queryOne('SELECT id FROM events WHERE id = $1', [req.params.id]),
      queryOne('SELECT id FROM customers WHERE id = $1', [customerId]),
      queryOne<{ id: string; product_type: string }>('SELECT id, product_type FROM products WHERE id = $1', [productId]),
    ]);

    if (!event)    throw new NotFoundError('Event not found');
    if (!customer) throw new NotFoundError('Customer not found');
    if (!product)  throw new NotFoundError('Product not found');

    const cp = await queryOne(
      `INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, notes, status)
       VALUES ($1, $2, $3, $4, $5, 'active')
       ON CONFLICT (customer_id, product_id, event_id) DO NOTHING
       RETURNING *`,
      [customerId, productId, req.params.id, pricePaidCents ?? null, notes ?? null]
    );

    if (!cp) {
      throw new BadRequestError('This customer already has this product for this event');
    }

    res.status(201).json({ customerProduct: cp, message: 'Partner added to event' });
  } catch (error) {
    next(error);
  }
});

router.delete('/events/:id/partners/:customerProductId', async (req, res, next): Promise<void> => {
  try {
    const existing = await queryOne(
      'SELECT id FROM customer_products WHERE id = $1 AND event_id = $2',
      [req.params.customerProductId, req.params.id]
    );

    if (!existing) throw new NotFoundError('Partner association not found');

    await query('DELETE FROM customer_products WHERE id = $1', [req.params.customerProductId]);

    res.json({ message: 'Partner removed from event' });
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
// CUSTOMERS
// ================================================================

const listCustomersSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    q: z.string().optional(),
    hasProductType: z.enum(['sponsorship', 'vendor_space', 'data_product']).optional(),
    marketId: z.string().uuid().optional(),
  }),
});

router.get('/customers', validate(listCustomersSchema), async (req, res, next) => {
  try {
    const { q, hasProductType, marketId, limit, offset } = req.query as any;

    let whereClause = 'WHERE 1=1';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (q) {
      whereClause += ` AND (c.name ILIKE $${paramIndex})`;
      params.push(`%${q}%`);
      paramIndex++;
    }

    if (hasProductType) {
      whereClause += ` AND EXISTS (
        SELECT 1 FROM customer_products cp
        JOIN products p ON p.id = cp.product_id
        WHERE cp.customer_id = c.id AND p.product_type = $${paramIndex++}
      )`;
      params.push(hasProductType);
    }

    if (marketId) {
      whereClause += ` AND EXISTS (
        SELECT 1 FROM customer_markets cm WHERE cm.customer_id = c.id AND cm.market_id = $${paramIndex++}
      )`;
      params.push(marketId);
    }

    params.push(limit, offset);

    const customers = await query(
      `SELECT c.*,
              COALESCE(
                (SELECT json_agg(DISTINCT p.product_type)
                 FROM customer_products cp JOIN products p ON p.id = cp.product_id
                 WHERE cp.customer_id = c.id AND cp.status = 'active'),
                '[]'::json
              ) AS active_product_types,
              COALESCE(
                (SELECT json_agg(json_build_object('id', m.id, 'name', m.name, 'slug', m.slug))
                 FROM customer_markets cm JOIN markets m ON m.id = cm.market_id
                 WHERE cm.customer_id = c.id),
                '[]'::json
              ) AS markets
       FROM customers c
       ${whereClause}
       ORDER BY c.name ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ customers });
  } catch (error) {
    next(error);
  }
});

router.get('/customers/:id', async (req, res, next) => {
  try {
    const customer = await queryOne(
      `SELECT c.*,
              COALESCE(
                (SELECT json_agg(json_build_object(
                  'id', cp.id, 'product_id', cp.product_id,
                  'product_name', p.name, 'product_type', p.product_type,
                  'config', p.config, 'event_id', cp.event_id,
                  'event_name', ev.name,
                  'price_paid_cents', cp.price_paid_cents,
                  'status', cp.status, 'start_date', cp.start_date,
                  'end_date', cp.end_date, 'notes', cp.notes,
                  'created_at', cp.created_at
                ) ORDER BY cp.created_at DESC)
                 FROM customer_products cp
                 JOIN products p ON p.id = cp.product_id
                 LEFT JOIN events ev ON ev.id = cp.event_id
                 WHERE cp.customer_id = c.id),
                '[]'::json
              ) AS products,
              COALESCE(
                (SELECT json_agg(json_build_object(
                  'id', d.id, 'title', d.title, 'description', d.description,
                  'type', d.type, 'value', d.value, 'code', d.code,
                  'terms', d.terms, 'is_active', d.is_active,
                  'start_date', d.start_date, 'end_date', d.end_date,
                  'redemption_count', (SELECT COUNT(*)::int FROM discount_redemptions WHERE discount_id = d.id),
                  'created_at', d.created_at
                ) ORDER BY d.created_at DESC)
                 FROM discounts d WHERE d.customer_id = c.id),
                '[]'::json
              ) AS discounts,
              COALESCE(
                (SELECT json_agg(json_build_object(
                  'id', cc.id, 'customer_id', cc.customer_id,
                  'name', cc.name, 'email', cc.email, 'phone', cc.phone,
                  'role', cc.role, 'title', cc.title,
                  'is_primary', cc.is_primary, 'notes', cc.notes,
                  'created_at', cc.created_at, 'updated_at', cc.updated_at
                ) ORDER BY cc.is_primary DESC, cc.name ASC)
                 FROM customer_contacts cc WHERE cc.customer_id = c.id),
                '[]'::json
              ) AS contacts,
              COALESCE(
                (SELECT json_agg(json_build_object(
                  'id', m.id, 'name', m.name, 'slug', m.slug,
                  'timezone', m.timezone, 'is_active', m.is_active
                ) ORDER BY m.sort_order ASC)
                 FROM customer_markets cm JOIN markets m ON m.id = cm.market_id
                 WHERE cm.customer_id = c.id),
                '[]'::json
              ) AS markets,
              COALESCE(
                (SELECT json_agg(json_build_object(
                  'id', cmedia.id, 'customer_id', cmedia.customer_id,
                  'url', cmedia.url, 'placement', cmedia.placement,
                  'width', cmedia.width, 'height', cmedia.height,
                  'alt_text', cmedia.alt_text, 'sort_order', cmedia.sort_order,
                  'uploaded_at', cmedia.uploaded_at
                ) ORDER BY cmedia.sort_order ASC, cmedia.uploaded_at DESC)
                 FROM customer_media cmedia WHERE cmedia.customer_id = c.id),
                '[]'::json
              ) AS media
       FROM customers c
       WHERE c.id = $1`,
      [req.params.id]
    );

    if (!customer) throw new NotFoundError('Customer not found');

    res.json({ customer });
  } catch (error) {
    next(error);
  }
});

const createCustomerSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    description: z.string().optional(),
    website: z.string().url().optional(),
    logoUrl: z.string().url().optional(),
    contactEmail: z.string().email().optional(),
    contactPhone: z.string().optional(),
    notes: z.string().optional(),
    marketIds: z.array(z.string().uuid()).optional(),
  }),
});

router.post('/customers', validate(createCustomerSchema), async (req, res, next) => {
  try {
    const { name, description, website, logoUrl, contactEmail, contactPhone, notes, marketIds } = req.body;
    const customer = await queryOne(
      `INSERT INTO customers (name, description, website, logo_url, contact_email, contact_phone, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [name, description ?? null, website ?? null, logoUrl ?? null, contactEmail ?? null, contactPhone ?? null, notes ?? null]
    );

    // Sync market associations
    if (marketIds && marketIds.length > 0 && customer) {
      const values = marketIds.map((_: string, i: number) => `($1, $${i + 2})`).join(', ');
      await query(
        `INSERT INTO customer_markets (customer_id, market_id) VALUES ${values}`,
        [(customer as any).id, ...marketIds]
      );
    }

    res.status(201).json({ customer });
  } catch (error) {
    next(error);
  }
});

const updateCustomerSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    description: z.string().nullable().optional(),
    website: z.string().url().nullable().optional(),
    logoUrl: z.string().url().nullable().optional(),
    contactEmail: z.string().email().nullable().optional(),
    contactPhone: z.string().nullable().optional(),
    notes: z.string().nullable().optional(),
    isActive: z.boolean().optional(),
    marketIds: z.array(z.string().uuid()).nullable().optional(),
  }),
});

router.patch('/customers/:id', validate(updateCustomerSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, website, logoUrl, contactEmail, contactPhone, notes, isActive, marketIds } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name !== undefined)         { updates.push(`name = $${paramIndex++}`);          params.push(name); }
    if (description !== undefined)  { updates.push(`description = $${paramIndex++}`);   params.push(description); }
    if (website !== undefined)      { updates.push(`website = $${paramIndex++}`);       params.push(website); }
    if (logoUrl !== undefined)      { updates.push(`logo_url = $${paramIndex++}`);      params.push(logoUrl); }
    if (contactEmail !== undefined) { updates.push(`contact_email = $${paramIndex++}`); params.push(contactEmail); }
    if (contactPhone !== undefined) { updates.push(`contact_phone = $${paramIndex++}`); params.push(contactPhone); }
    if (notes !== undefined)        { updates.push(`notes = $${paramIndex++}`);         params.push(notes); }
    if (isActive !== undefined)     { updates.push(`is_active = $${paramIndex++}`);     params.push(isActive); }

    if (updates.length === 0 && marketIds === undefined) {
      const customer = await queryOne('SELECT * FROM customers WHERE id = $1', [req.params.id]);
      if (!customer) throw new NotFoundError('Customer not found');
      res.json({ customer });
      return;
    }

    let customer: any;
    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      params.push(req.params.id);
      customer = await queryOne(
        `UPDATE customers SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
        params
      );
    } else {
      customer = await queryOne('SELECT * FROM customers WHERE id = $1', [req.params.id]);
    }

    if (!customer) throw new NotFoundError('Customer not found');

    // Sync market associations (replace all)
    if (marketIds !== undefined) {
      await query('DELETE FROM customer_markets WHERE customer_id = $1', [req.params.id]);
      if (marketIds && marketIds.length > 0) {
        const values = marketIds.map((_: string, i: number) => `($1, $${i + 2})`).join(', ');
        await query(
          `INSERT INTO customer_markets (customer_id, market_id) VALUES ${values}`,
          [req.params.id, ...marketIds]
        );
      }
    }

    res.json({ customer });
  } catch (error) {
    next(error);
  }
});

router.delete('/customers/:id', async (req, res, next): Promise<void> => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    await query('DELETE FROM customers WHERE id = $1', [req.params.id]);
    res.json({ message: 'Customer deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// CUSTOMER CONTACTS
// ================================================================

// GET /admin/customers/:id/contacts
router.get('/customers/:id/contacts', async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const contacts = await query(
      `SELECT * FROM customer_contacts WHERE customer_id = $1 ORDER BY is_primary DESC, name ASC`,
      [req.params.id]
    );
    res.json({ contacts });
  } catch (error) {
    next(error);
  }
});

const createContactSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(255),
    email: z.string().email().max(255).optional(),
    phone: z.string().max(20).optional(),
    role: z.enum(['primary', 'billing', 'decision_maker', 'other']).default('other'),
    title: z.string().max(255).optional(),
    isPrimary: z.boolean().default(false),
    notes: z.string().optional(),
  }),
});

// POST /admin/customers/:id/contacts
router.post('/customers/:id/contacts', validate(createContactSchema), async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const { name, email, phone, role, title, isPrimary, notes } = req.body;

    // If setting as primary, unset any existing primary
    if (isPrimary) {
      await query(
        `UPDATE customer_contacts SET is_primary = false WHERE customer_id = $1 AND is_primary = true`,
        [req.params.id]
      );
    }

    const contact = await queryOne(
      `INSERT INTO customer_contacts (customer_id, name, email, phone, role, title, is_primary, notes)
       VALUES ($1, $2, $3, $4, $5::contact_role, $6, $7, $8) RETURNING *`,
      [req.params.id, name, email ?? null, phone ?? null, role, title ?? null, isPrimary, notes ?? null]
    );

    res.status(201).json({ contact });
  } catch (error) {
    next(error);
  }
});

const updateContactSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(255).optional(),
    email: z.string().email().max(255).nullable().optional(),
    phone: z.string().max(20).nullable().optional(),
    role: z.enum(['primary', 'billing', 'decision_maker', 'other']).optional(),
    title: z.string().max(255).nullable().optional(),
    isPrimary: z.boolean().optional(),
    notes: z.string().nullable().optional(),
  }),
});

// PATCH /admin/customers/:id/contacts/:contactId
router.patch('/customers/:id/contacts/:contactId', validate(updateContactSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, email, phone, role, title, isPrimary, notes } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name !== undefined)      { updates.push(`name = $${paramIndex++}`);       params.push(name); }
    if (email !== undefined)     { updates.push(`email = $${paramIndex++}`);      params.push(email); }
    if (phone !== undefined)     { updates.push(`phone = $${paramIndex++}`);      params.push(phone); }
    if (role !== undefined)      { updates.push(`role = $${paramIndex++}::contact_role`); params.push(role); }
    if (title !== undefined)     { updates.push(`title = $${paramIndex++}`);      params.push(title); }
    if (isPrimary !== undefined) { updates.push(`is_primary = $${paramIndex++}`); params.push(isPrimary); }
    if (notes !== undefined)     { updates.push(`notes = $${paramIndex++}`);      params.push(notes); }

    if (updates.length === 0) {
      const contact = await queryOne(
        'SELECT * FROM customer_contacts WHERE id = $1 AND customer_id = $2',
        [req.params.contactId, req.params.id]
      );
      if (!contact) throw new NotFoundError('Contact not found');
      res.json({ contact });
      return;
    }

    // If setting as primary, unset any existing primary first
    if (isPrimary) {
      await query(
        `UPDATE customer_contacts SET is_primary = false WHERE customer_id = $1 AND is_primary = true AND id != $2`,
        [req.params.id, req.params.contactId]
      );
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.contactId, req.params.id);

    const contact = await queryOne(
      `UPDATE customer_contacts SET ${updates.join(', ')} WHERE id = $${paramIndex} AND customer_id = $${paramIndex + 1} RETURNING *`,
      params
    );

    if (!contact) throw new NotFoundError('Contact not found');

    res.json({ contact });
  } catch (error) {
    next(error);
  }
});

// DELETE /admin/customers/:id/contacts/:contactId
router.delete('/customers/:id/contacts/:contactId', async (req, res, next): Promise<void> => {
  try {
    const contact = await queryOne(
      'SELECT id FROM customer_contacts WHERE id = $1 AND customer_id = $2',
      [req.params.contactId, req.params.id]
    );
    if (!contact) throw new NotFoundError('Contact not found');

    await query('DELETE FROM customer_contacts WHERE id = $1', [req.params.contactId]);
    res.json({ message: 'Contact deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// CUSTOMER MEDIA (brand assets)
// ================================================================

// POST /admin/customers/:id/media — upload brand asset
router.post('/customers/:id/media', upload.single('image'), async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    if (!req.file) throw new BadRequestError('No image file provided');

    const placement = (req.body.placement as string) || 'other';
    const validPlacements = ['app_banner', 'web_banner', 'social_media', 'logo', 'other'];
    if (!validPlacements.includes(placement)) {
      throw new BadRequestError(`Invalid placement: ${placement}. Must be one of: ${validPlacements.join(', ')}`);
    }

    // Process with sharp (resize, get dimensions)
    const processed = await sharp(req.file.buffer)
      .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
      .toBuffer({ resolveWithObject: true });

    const url = await uploadImage(processed.data, req.file.originalname, `customers/${req.params.id}`);

    const media = await queryOne(
      `INSERT INTO customer_media (customer_id, url, placement, width, height)
       VALUES ($1, $2, $3::media_placement, $4, $5) RETURNING *`,
      [req.params.id, url, placement, processed.info.width, processed.info.height]
    );

    res.status(201).json({ media });
  } catch (error) {
    next(error);
  }
});

// DELETE /admin/customers/:id/media/:mediaId
router.delete('/customers/:id/media/:mediaId', async (req, res, next): Promise<void> => {
  try {
    const media = await queryOne<{ id: string; url: string }>(
      'SELECT id, url FROM customer_media WHERE id = $1 AND customer_id = $2',
      [req.params.mediaId, req.params.id]
    );
    if (!media) throw new NotFoundError('Media not found');

    await deleteImage(media.url);
    await query('DELETE FROM customer_media WHERE id = $1', [req.params.mediaId]);

    res.json({ message: 'Media deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// PRODUCTS (catalog)
// ================================================================

const listProductsSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    type: z.enum(['sponsorship', 'vendor_space', 'data_product']).optional(),
    isStandard: z.enum(['true', 'false']).optional(),
  }),
});

router.get('/products', validate(listProductsSchema), async (req, res, next) => {
  try {
    const { type, isStandard, limit, offset } = req.query as any;

    let whereClause = 'WHERE 1=1';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (type) {
      whereClause += ` AND product_type = $${paramIndex++}`;
      params.push(type);
    }
    if (isStandard !== undefined) {
      whereClause += ` AND is_standard = $${paramIndex++}`;
      params.push(isStandard === 'true');
    }

    params.push(limit, offset);

    const products = await query(
      `SELECT * FROM products ${whereClause}
       ORDER BY sort_order ASC, name ASC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ products });
  } catch (error) {
    next(error);
  }
});

const createProductSchema = z.object({
  body: z.object({
    productType: z.enum(['sponsorship', 'vendor_space', 'data_product']),
    name: z.string().min(1),
    description: z.string().optional(),
    basePriceCents: z.number().int().min(0).optional(),
    isStandard: z.boolean().default(true),
    config: z.record(z.unknown()).default({}),
    sortOrder: z.number().int().default(0),
  }),
});

router.post('/products', validate(createProductSchema), async (req, res, next) => {
  try {
    const { productType, name, description, basePriceCents, isStandard, config, sortOrder } = req.body;
    const product = await queryOne(
      `INSERT INTO products (product_type, name, description, base_price_cents, is_standard, config, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [productType, name, description ?? null, basePriceCents ?? null, isStandard, JSON.stringify(config), sortOrder]
    );
    res.status(201).json({ product });
  } catch (error) {
    next(error);
  }
});

const updateProductSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    description: z.string().nullable().optional(),
    basePriceCents: z.number().int().min(0).nullable().optional(),
    config: z.record(z.unknown()).optional(),
    isActive: z.boolean().optional(),
    sortOrder: z.number().int().optional(),
  }),
});

router.patch('/products/:id', validate(updateProductSchema), async (req, res, next): Promise<void> => {
  try {
    const { name, description, basePriceCents, config, isActive, sortOrder } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (name !== undefined)           { updates.push(`name = $${paramIndex++}`);             params.push(name); }
    if (description !== undefined)    { updates.push(`description = $${paramIndex++}`);      params.push(description); }
    if (basePriceCents !== undefined) { updates.push(`base_price_cents = $${paramIndex++}`); params.push(basePriceCents); }
    if (config !== undefined)         { updates.push(`config = $${paramIndex++}`);           params.push(JSON.stringify(config)); }
    if (isActive !== undefined)       { updates.push(`is_active = $${paramIndex++}`);        params.push(isActive); }
    if (sortOrder !== undefined)      { updates.push(`sort_order = $${paramIndex++}`);       params.push(sortOrder); }

    if (updates.length === 0) {
      const product = await queryOne('SELECT * FROM products WHERE id = $1', [req.params.id]);
      if (!product) throw new NotFoundError('Product not found');
      res.json({ product });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.id);

    const product = await queryOne(
      `UPDATE products SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    if (!product) throw new NotFoundError('Product not found');

    res.json({ product });
  } catch (error) {
    next(error);
  }
});

router.delete('/products/:id', async (req, res, next): Promise<void> => {
  try {
    const product = await queryOne('SELECT id FROM products WHERE id = $1', [req.params.id]);
    if (!product) throw new NotFoundError('Product not found');

    // RESTRICT: cannot delete if customer_products reference it
    const inUse = await queryOne(
      'SELECT id FROM customer_products WHERE product_id = $1 LIMIT 1',
      [req.params.id]
    );
    if (inUse) {
      throw new BadRequestError('Cannot delete product that has been purchased by customers. Deactivate it instead.');
    }

    await query('DELETE FROM products WHERE id = $1', [req.params.id]);
    res.json({ message: 'Product deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// CUSTOMER PRODUCTS (purchases / subscriptions)
// ================================================================

router.get('/customers/:id/products', async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const products = await query(
      `SELECT cp.*, p.name AS product_name, p.product_type, p.config,
              ev.name AS event_name
       FROM customer_products cp
       JOIN products p ON p.id = cp.product_id
       LEFT JOIN events ev ON ev.id = cp.event_id
       WHERE cp.customer_id = $1
       ORDER BY cp.created_at DESC`,
      [req.params.id]
    );

    res.json({ products });
  } catch (error) {
    next(error);
  }
});

const addCustomerProductSchema = z.object({
  body: z.object({
    productId: z.string().uuid(),
    eventId: z.string().uuid().optional(),
    pricePaidCents: z.number().int().min(0).optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    configOverrides: z.record(z.unknown()).default({}),
    notes: z.string().optional(),
  }),
});

router.post('/customers/:id/products', validate(addCustomerProductSchema), async (req, res, next) => {
  try {
    const { productId, eventId, pricePaidCents, startDate, endDate, configOverrides, notes } = req.body;

    const [customer, product] = await Promise.all([
      queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]),
      queryOne('SELECT id FROM products WHERE id = $1', [productId]),
    ]);

    if (!customer) throw new NotFoundError('Customer not found');
    if (!product) throw new NotFoundError('Product not found');

    if (eventId) {
      const event = await queryOne('SELECT id FROM events WHERE id = $1', [eventId]);
      if (!event) throw new NotFoundError('Event not found');
    }

    const cp = await queryOne(
      `INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, start_date, end_date, config_overrides, notes, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active')
       RETURNING *`,
      [req.params.id, productId, eventId ?? null, pricePaidCents ?? null, startDate ?? null, endDate ?? null, JSON.stringify(configOverrides), notes ?? null]
    );

    res.status(201).json({ customerProduct: cp });
  } catch (error) {
    next(error);
  }
});

const updateCustomerProductSchema = z.object({
  body: z.object({
    status: z.enum(['active', 'expired', 'cancelled', 'pending']).optional(),
    pricePaidCents: z.number().int().min(0).optional(),
    startDate: z.string().nullable().optional(),
    endDate: z.string().nullable().optional(),
    notes: z.string().nullable().optional(),
  }),
});

router.patch('/customers/:id/products/:cpId', validate(updateCustomerProductSchema), async (req, res, next): Promise<void> => {
  try {
    const { status, pricePaidCents, startDate, endDate, notes } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (status !== undefined)         { updates.push(`status = $${paramIndex++}`);           params.push(status); }
    if (pricePaidCents !== undefined)  { updates.push(`price_paid_cents = $${paramIndex++}`); params.push(pricePaidCents); }
    if (startDate !== undefined)       { updates.push(`start_date = $${paramIndex++}`);       params.push(startDate); }
    if (endDate !== undefined)         { updates.push(`end_date = $${paramIndex++}`);         params.push(endDate); }
    if (notes !== undefined)           { updates.push(`notes = $${paramIndex++}`);            params.push(notes); }

    if (updates.length === 0) {
      const cp = await queryOne(
        'SELECT * FROM customer_products WHERE id = $1 AND customer_id = $2',
        [req.params.cpId, req.params.id]
      );
      if (!cp) throw new NotFoundError('Customer product not found');
      res.json({ customerProduct: cp });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.cpId, req.params.id);

    const cp = await queryOne(
      `UPDATE customer_products SET ${updates.join(', ')}
       WHERE id = $${paramIndex} AND customer_id = $${paramIndex + 1}
       RETURNING *`,
      params
    );

    if (!cp) throw new NotFoundError('Customer product not found');

    res.json({ customerProduct: cp });
  } catch (error) {
    next(error);
  }
});

router.delete('/customers/:id/products/:cpId', async (req, res, next): Promise<void> => {
  try {
    const cp = await queryOne(
      'SELECT id FROM customer_products WHERE id = $1 AND customer_id = $2',
      [req.params.cpId, req.params.id]
    );
    if (!cp) throw new NotFoundError('Customer product not found');

    await query('DELETE FROM customer_products WHERE id = $1', [req.params.cpId]);
    res.json({ message: 'Customer product removed' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// DISCOUNTS (perks offered by customers to app users)
// ================================================================

router.get('/customers/:id/discounts', async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const discounts = await query(
      `SELECT d.*,
              (SELECT COUNT(*)::int FROM discount_redemptions WHERE discount_id = d.id) AS redemption_count
       FROM discounts d
       WHERE d.customer_id = $1
       ORDER BY d.created_at DESC`,
      [req.params.id]
    );

    res.json({ discounts });
  } catch (error) {
    next(error);
  }
});

const createDiscountSchema = z.object({
  body: z.object({
    title: z.string().min(1),
    description: z.string().optional(),
    type: z.enum(['percentage', 'fixedAmount', 'freeItem', 'buyOneGetOne', 'other']).default('percentage'),
    value: z.number().min(0).optional(),
    code: z.string().optional(),
    terms: z.string().optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
  }),
});

router.post('/customers/:id/discounts', validate(createDiscountSchema), async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const { title, description, type, value, code, terms, startDate, endDate } = req.body;
    const discount = await queryOne(
      `INSERT INTO discounts (customer_id, title, description, type, value, code, terms, start_date, end_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [req.params.id, title, description ?? null, type, value ?? null, code ?? null, terms ?? null, startDate ?? null, endDate ?? null]
    );

    res.status(201).json({ discount });
  } catch (error) {
    next(error);
  }
});

const updateDiscountSchema = z.object({
  body: z.object({
    title: z.string().min(1).optional(),
    description: z.string().nullable().optional(),
    type: z.enum(['percentage', 'fixedAmount', 'freeItem', 'buyOneGetOne', 'other']).optional(),
    value: z.number().min(0).nullable().optional(),
    code: z.string().nullable().optional(),
    terms: z.string().nullable().optional(),
    isActive: z.boolean().optional(),
    startDate: z.string().nullable().optional(),
    endDate: z.string().nullable().optional(),
  }),
});

router.patch('/customers/:id/discounts/:discountId', validate(updateDiscountSchema), async (req, res, next): Promise<void> => {
  try {
    const { title, description, type, value, code, terms, isActive, startDate, endDate } = req.body;

    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (title !== undefined)       { updates.push(`title = $${paramIndex++}`);       params.push(title); }
    if (description !== undefined) { updates.push(`description = $${paramIndex++}`); params.push(description); }
    if (type !== undefined)        { updates.push(`type = $${paramIndex++}`);        params.push(type); }
    if (value !== undefined)       { updates.push(`value = $${paramIndex++}`);       params.push(value); }
    if (code !== undefined)        { updates.push(`code = $${paramIndex++}`);        params.push(code); }
    if (terms !== undefined)       { updates.push(`terms = $${paramIndex++}`);       params.push(terms); }
    if (isActive !== undefined)    { updates.push(`is_active = $${paramIndex++}`);   params.push(isActive); }
    if (startDate !== undefined)   { updates.push(`start_date = $${paramIndex++}`);  params.push(startDate); }
    if (endDate !== undefined)     { updates.push(`end_date = $${paramIndex++}`);    params.push(endDate); }

    if (updates.length === 0) {
      const discount = await queryOne(
        'SELECT * FROM discounts WHERE id = $1 AND customer_id = $2',
        [req.params.discountId, req.params.id]
      );
      if (!discount) throw new NotFoundError('Discount not found');
      res.json({ discount });
      return;
    }

    updates.push('updated_at = NOW()');
    params.push(req.params.discountId, req.params.id);

    const discount = await queryOne(
      `UPDATE discounts SET ${updates.join(', ')}
       WHERE id = $${paramIndex} AND customer_id = $${paramIndex + 1}
       RETURNING *`,
      params
    );

    if (!discount) throw new NotFoundError('Discount not found');

    res.json({ discount });
  } catch (error) {
    next(error);
  }
});

router.delete('/customers/:id/discounts/:discountId', async (req, res, next): Promise<void> => {
  try {
    const discount = await queryOne(
      'SELECT id FROM discounts WHERE id = $1 AND customer_id = $2',
      [req.params.discountId, req.params.id]
    );
    if (!discount) throw new NotFoundError('Discount not found');

    await query('DELETE FROM discounts WHERE id = $1', [req.params.discountId]);
    res.json({ message: 'Discount deleted' });
  } catch (error) {
    next(error);
  }
});

// ================================================================
// DISCOUNT REDEMPTIONS (admin analytics view)
// ================================================================

router.get('/customers/:id/redemptions', async (req, res, next) => {
  try {
    const customer = await queryOne('SELECT id FROM customers WHERE id = $1', [req.params.id]);
    if (!customer) throw new NotFoundError('Customer not found');

    const stats = await query(
      `SELECT d.id AS discount_id, d.title, d.code,
              COUNT(dr.id)::int AS redemption_count,
              MAX(dr.redeemed_at) AS last_redeemed_at
       FROM discounts d
       LEFT JOIN discount_redemptions dr ON dr.discount_id = d.id
       WHERE d.customer_id = $1
       GROUP BY d.id, d.title, d.code
       ORDER BY redemption_count DESC`,
      [req.params.id]
    );

    res.json({ redemptions: stats });
  } catch (error) {
    next(error);
  }
});

router.get('/discounts/:id/redemptions', async (req, res, next) => {
  try {
    const discount = await queryOne('SELECT id FROM discounts WHERE id = $1', [req.params.id]);
    if (!discount) throw new NotFoundError('Discount not found');

    const redemptions = await query(
      `SELECT dr.*, u.name AS user_name, u.phone AS user_phone
       FROM discount_redemptions dr
       JOIN users u ON u.id = dr.user_id
       WHERE dr.discount_id = $1
       ORDER BY dr.redeemed_at DESC`,
      [req.params.id]
    );

    res.json({ redemptions });
  } catch (error) {
    next(error);
  }
});

export default router;

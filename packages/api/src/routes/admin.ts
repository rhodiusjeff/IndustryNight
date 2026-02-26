import { Router } from 'express';
import { z } from 'zod';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticateAdmin } from '../middleware/admin-auth';
import { query, queryOne } from '../config/database';
import { generateActivationCode } from '../utils/jwt';
import { NotFoundError } from '../utils/errors';

const router = Router();

// All admin routes require admin authentication
router.use(authenticateAdmin);

// Dashboard stats
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
        (SELECT COUNT(*) FROM users WHERE banned = false) as total_users,
        (SELECT COUNT(*) FROM users WHERE verification_status = 'verified') as verified_users,
        (SELECT COUNT(*) FROM events) as total_events,
        (SELECT COUNT(*) FROM events WHERE start_time > NOW() AND status = 'published') as upcoming_events,
        (SELECT COUNT(*) FROM connections) as total_connections,
        (SELECT COUNT(*) FROM posts WHERE is_hidden = false) as total_posts
    `);

    res.json({ stats });
  } catch (error) {
    next(error);
  }
});

// List users
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

// Update user
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

    if (role !== undefined) {
      updates.push(`role = $${paramIndex++}`);
      params.push(role);
    }
    if (banned !== undefined) {
      updates.push(`banned = $${paramIndex++}`);
      params.push(banned);
    }
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

    if (!user) {
      throw new NotFoundError('User not found');
    }

    res.json({ user });
  } catch (error) {
    next(error);
  }
});

// Add user
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

// List events
router.get('/events', validate(paginationSchema), async (req, res, next) => {
  try {
    const { limit, offset } = req.query as any;

    const events = await query(
      `SELECT * FROM events ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json({ events });
  } catch (error) {
    next(error);
  }
});

// Create event
const createEventSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    venueId: z.string().uuid(),
    startTime: z.string().datetime(),
    endTime: z.string().datetime(),
    description: z.string().optional(),
    capacity: z.number().positive().optional(),
  }),
});

router.post('/events', validate(createEventSchema), async (req, res, next) => {
  try {
    const { name, venueId, startTime, endTime, description, capacity } = req.body;
    const activationCode = generateActivationCode();

    const event = await queryOne(
      `INSERT INTO events (name, venue_id, start_time, end_time, description, capacity, activation_code)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [name, venueId, startTime, endTime, description, capacity, activationCode]
    );

    res.status(201).json({ event });
  } catch (error) {
    next(error);
  }
});

// Update event
const updateEventSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    description: z.string().optional(),
    startTime: z.string().datetime().optional(),
    endTime: z.string().datetime().optional(),
    status: z.enum(['draft', 'published', 'cancelled', 'completed']).optional(),
    capacity: z.number().positive().optional(),
  }),
});

router.patch('/events/:id', validate(updateEventSchema), async (req, res, next): Promise<void> => {
  try {
    const updates: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    Object.entries(req.body).forEach(([key, value]) => {
      if (value !== undefined) {
        const dbKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
        updates.push(`${dbKey} = $${paramIndex++}`);
        params.push(value);
      }
    });

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

    res.json({ event });
  } catch (error) {
    next(error);
  }
});

// Sponsors
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

// Vendors
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

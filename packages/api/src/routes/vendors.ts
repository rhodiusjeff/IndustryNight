import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List active vendors (public)
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const vendors = await query(
      `SELECT id, name, description, logo_url, website, category
       FROM vendors
       WHERE is_active = true
       ORDER BY name ASC`
    );

    res.json({ vendors });
  } catch (error) {
    next(error);
  }
});

export default router;

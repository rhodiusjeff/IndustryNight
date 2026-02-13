import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List all active discounts
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const discounts = await query(
      `SELECT d.*, s.name as sponsor_name, s.logo_url as sponsor_logo
       FROM discounts d
       JOIN sponsors s ON d.sponsor_id = s.id
       WHERE d.is_active = true AND s.is_active = true
       AND (d.start_date IS NULL OR d.start_date <= NOW())
       AND (d.end_date IS NULL OR d.end_date >= NOW())
       ORDER BY s.tier DESC, d.created_at DESC`
    );

    res.json({ discounts });
  } catch (error) {
    next(error);
  }
});

export default router;

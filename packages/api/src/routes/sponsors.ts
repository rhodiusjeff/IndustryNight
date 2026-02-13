import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List active sponsors (public)
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const sponsors = await query(
      `SELECT id, name, description, logo_url, website, tier
       FROM sponsors
       WHERE is_active = true
       ORDER BY tier DESC, name ASC`
    );

    res.json({ sponsors });
  } catch (error) {
    next(error);
  }
});

// Get sponsor with discounts
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const sponsor = await query(
      `SELECT * FROM sponsors WHERE id = $1 AND is_active = true`,
      [req.params.id]
    );

    const discounts = await query(
      `SELECT * FROM discounts
       WHERE sponsor_id = $1 AND is_active = true
       AND (start_date IS NULL OR start_date <= NOW())
       AND (end_date IS NULL OR end_date >= NOW())`,
      [req.params.id]
    );

    res.json({ sponsor: sponsor[0], discounts });
  } catch (error) {
    next(error);
  }
});

export default router;

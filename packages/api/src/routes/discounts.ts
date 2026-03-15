import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List all active discounts with customer info
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const discounts = await query(
      `SELECT d.id, d.customer_id, d.title, d.description, d.type, d.value,
              d.code, d.terms, d.start_date, d.end_date, d.created_at,
              c.name as customer_name, c.logo_url as customer_logo
       FROM discounts d
       JOIN customers c ON d.customer_id = c.id
       WHERE d.is_active = true AND c.is_active = true
       AND (d.start_date IS NULL OR d.start_date <= NOW())
       AND (d.end_date IS NULL OR d.end_date >= NOW())
       ORDER BY d.created_at DESC`
    );

    res.json({ discounts });
  } catch (error) {
    next(error);
  }
});

// Redeem a discount ("I Used This")
router.post('/:id/redeem', authenticate, async (req, res, next) => {
  try {
    const discountId = req.params.id;
    const userId = req.user!.userId;

    // Verify discount exists and is active
    const discounts = await query(
      `SELECT id FROM discounts
       WHERE id = $1 AND is_active = true
       AND (start_date IS NULL OR start_date <= NOW())
       AND (end_date IS NULL OR end_date >= NOW())`,
      [discountId]
    );

    if (discounts.length === 0) {
      res.status(404).json({ error: 'Discount not found or not active' });
      return;
    }

    // Insert redemption (unique constraint prevents duplicates)
    const redemptions = await query(
      `INSERT INTO discount_redemptions (discount_id, user_id, method)
       VALUES ($1, $2, 'self_reported')
       ON CONFLICT (discount_id, user_id) DO NOTHING
       RETURNING id, redeemed_at`,
      [discountId, userId]
    );

    if (redemptions.length === 0) {
      res.status(409).json({ error: 'Already redeemed' });
      return;
    }

    res.status(201).json({ redemption: redemptions[0] });
  } catch (error) {
    next(error);
  }
});

// Check if current user has redeemed a discount
router.get('/:id/redeemed', authenticate, async (req, res, next) => {
  try {
    const redemptions = await query(
      `SELECT id, redeemed_at, method FROM discount_redemptions
       WHERE discount_id = $1 AND user_id = $2`,
      [req.params.id, req.user!.userId]
    );

    res.json({ redeemed: redemptions.length > 0, redemption: redemptions[0] || null });
  } catch (error) {
    next(error);
  }
});

export default router;

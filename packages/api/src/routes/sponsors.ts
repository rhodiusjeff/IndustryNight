import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List active sponsors (customers with sponsorship products)
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const sponsors = await query(
      `SELECT DISTINCT c.id, c.name, c.description, c.logo_url, c.website,
              MAX(p.config->>'tier') as tier
       FROM customers c
       JOIN customer_products cp ON cp.customer_id = c.id
       JOIN products p ON p.id = cp.product_id
       WHERE c.is_active = true
         AND cp.status = 'active'
         AND p.product_type = 'sponsorship'
       GROUP BY c.id
       ORDER BY tier DESC NULLS LAST, c.name ASC`
    );

    res.json({ sponsors });
  } catch (error) {
    next(error);
  }
});

// Get sponsor detail with discounts
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const customers = await query(
      `SELECT c.id, c.name, c.description, c.logo_url, c.website
       FROM customers c
       JOIN customer_products cp ON cp.customer_id = c.id
       JOIN products p ON p.id = cp.product_id
       WHERE c.id = $1 AND c.is_active = true
         AND cp.status = 'active'
         AND p.product_type = 'sponsorship'
       LIMIT 1`,
      [req.params.id]
    );

    if (customers.length === 0) {
      res.status(404).json({ error: 'Sponsor not found' });
      return;
    }

    const discounts = await query(
      `SELECT id, customer_id, title, description, type, value, code, terms,
              start_date, end_date, created_at
       FROM discounts
       WHERE customer_id = $1 AND is_active = true
       AND (start_date IS NULL OR start_date <= NOW())
       AND (end_date IS NULL OR end_date >= NOW())`,
      [req.params.id]
    );

    res.json({ sponsor: customers[0], discounts });
  } catch (error) {
    next(error);
  }
});

export default router;

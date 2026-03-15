import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { query } from '../config/database';

const router = Router();

// List active vendors (customers with vendor_space products)
router.get('/', authenticate, async (_req, res, next) => {
  try {
    const vendors = await query(
      `SELECT DISTINCT c.id, c.name, c.description, c.logo_url, c.website,
              MAX(p.config->>'category') as category
       FROM customers c
       JOIN customer_products cp ON cp.customer_id = c.id
       JOIN products p ON p.id = cp.product_id
       WHERE c.is_active = true
         AND cp.status = 'active'
         AND p.product_type = 'vendor_space'
       GROUP BY c.id
       ORDER BY c.name ASC`
    );

    res.json({ vendors });
  } catch (error) {
    next(error);
  }
});

export default router;

import { Router } from 'express';
import { z } from 'zod';
import { validate, phoneSchema } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import { generateTokenPair, verifyToken } from '../config/auth';
import { query, queryOne } from '../config/database';
import { verifyAvailable, sendVerification, checkVerification } from '../services/sms';
import { generateVerificationCode } from '../utils/jwt';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../utils/errors';

const router = Router();

function phoneDigits(phone: string): string {
  return phone.replace(/\D/g, '');
}

async function reconcilePoshOrdersForUser(userId: string, phone: string): Promise<{ linkedOrders: number; createdTickets: number }> {
  const fullDigits = phoneDigits(phone);
  const localDigits = fullDigits.length > 10 ? fullDigits.slice(-10) : fullDigits;

  const startedAt = Date.now();

  const result = await queryOne<{ linked_orders: number; created_tickets: number }>(
    `WITH linked_orders AS (
       UPDATE posh_orders
       SET user_id = $1
       WHERE user_id IS NULL
         AND account_phone IS NOT NULL
         AND (
           regexp_replace(account_phone, '[^0-9]', '', 'g') = $2
           OR regexp_replace(account_phone, '[^0-9]', '', 'g') = $3
           OR regexp_replace(account_phone, '[^0-9]', '', 'g') = ('1' || $3)
         )
       RETURNING event_id, order_number, total, date_purchased
     ),
     inserted_tickets AS (
       INSERT INTO tickets (user_id, event_id, posh_order_id, ticket_type, price, status, purchased_at)
       SELECT
         $1,
         lo.event_id,
         lo.order_number,
         'Posh',
         COALESCE(lo.total::numeric, 0),
         'purchased',
         COALESCE(lo.date_purchased, NOW())
       FROM linked_orders lo
       WHERE lo.event_id IS NOT NULL
         AND NOT EXISTS (
           SELECT 1
           FROM tickets t
           WHERE t.event_id = lo.event_id
             AND t.user_id = $1
             AND t.status NOT IN ('cancelled', 'refunded')
         )
       RETURNING id
     )
     SELECT
       (SELECT COUNT(*)::int FROM linked_orders) AS linked_orders,
       (SELECT COUNT(*)::int FROM inserted_tickets) AS created_tickets`,
    [userId, fullDigits, localDigits]
  );

  const linkedOrders = result?.linked_orders ?? 0;
  const createdTickets = result?.created_tickets ?? 0;
  const elapsedMs = Date.now() - startedAt;

  if (linkedOrders > 0 || createdTickets > 0) {
    console.log(
      `[AUTH] Reconciled Posh orders for ${phone}: linked=${linkedOrders}, tickets=${createdTickets}, durationMs=${elapsedMs}`
    );
  }

  return { linkedOrders, createdTickets };
}

// Request verification code
const requestCodeSchema = z.object({
  body: z.object({
    phone: phoneSchema,
  }),
});

router.post('/request-code', validate(requestCodeSchema), async (req, res, next): Promise<void> => {
  try {
    const { phone } = req.body;

    if (verifyAvailable) {
      // Use Twilio Verify — it handles code generation, storage, and delivery
      await sendVerification(phone);
      res.json({ message: 'Verification code sent' });
    } else {
      // Dev mode: generate and store code locally
      const code = generateVerificationCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

      await query(
        `INSERT INTO verification_codes (phone, code, expires_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (phone) DO UPDATE SET code = $2, expires_at = $3`,
        [phone, code, expiresAt]
      );

      console.log(`[SMS-DEV] Verification code for ${phone}: ${code}`);
      res.json({ message: 'Verification code sent', devCode: code });
    }
  } catch (error) {
    next(error);
  }
});

// Verify code
const verifyCodeSchema = z.object({
  body: z.object({
    phone: phoneSchema,
    code: z.string().length(6),
  }),
});

router.post('/verify-code', validate(verifyCodeSchema), async (req, res, next) => {
  try {
    const { phone, code } = req.body;

    if (verifyAvailable) {
      // Use Twilio Verify to check the code
      const approved = await checkVerification(phone, code);
      if (!approved) {
        throw new BadRequestError('Invalid verification code');
      }
    } else {
      // Dev mode: check code from our database
      const storedCode = await queryOne<{ code: string; expires_at: Date }>(
        'SELECT code, expires_at FROM verification_codes WHERE phone = $1',
        [phone]
      );

      if (!storedCode || storedCode.code !== code) {
        throw new BadRequestError('Invalid verification code');
      }

      if (new Date() > storedCode.expires_at) {
        throw new BadRequestError('Verification code expired');
      }

      // Delete used code
      await query('DELETE FROM verification_codes WHERE phone = $1', [phone]);
    }

    // Get or create user
    let user = await queryOne<{ id: string; role: string }>(
      'SELECT id, role FROM users WHERE phone = $1',
      [phone]
    );

    const isNewUser = !user;

    if (!user) {
      // Create new user on first verification
      user = await queryOne<{ id: string; role: string }>(
        'INSERT INTO users (phone, source) VALUES ($1, $2) RETURNING id, role',
        [phone, 'app']
      );
    }

    // Update last login
    await query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user!.id]);

    // Reconcile any pre-existing Posh orders for this phone number.
    const reconciliation = await reconcilePoshOrdersForUser(user!.id, phone);
    if (reconciliation.linkedOrders > 0 || reconciliation.createdTickets > 0) {
      console.log(
        `[AUTH] verify-code reconciliation for user=${user!.id}: linked=${reconciliation.linkedOrders}, tickets=${reconciliation.createdTickets}`
      );
    }

    // Generate tokens
    const tokens = generateTokenPair(user!.id, user!.role);

    // Get full user
    const fullUser = await queryOne(
      'SELECT * FROM users WHERE id = $1',
      [user!.id]
    );

    res.json({
      ...tokens,
      user: fullUser,
      isNewUser,
    });
  } catch (error) {
    next(error);
  }
});

// Refresh token
const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string(),
  }),
});

router.post('/refresh', validate(refreshSchema), async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    const payload = verifyToken(refreshToken);
    if (payload.type !== 'refresh' || payload.tokenFamily !== 'social') {
      throw new UnauthorizedError('Invalid refresh token');
    }

    const user = await queryOne<{ id: string; role: string; banned: boolean }>(
      'SELECT id, role, banned FROM users WHERE id = $1',
      [payload.userId]
    );

    if (!user || user.banned) {
      throw new UnauthorizedError('User not found or banned');
    }

    const tokens = generateTokenPair(user.id, user.role);
    const fullUser = await queryOne('SELECT * FROM users WHERE id = $1', [user.id]);

    res.json({
      ...tokens,
      user: fullUser,
    });
  } catch (error) {
    next(error);
  }
});

// Logout (client-side token deletion, but could add to blacklist)
router.post('/logout', authenticate, async (_req, res) => {
  res.json({ message: 'Logged out' });
});

// Get current user
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.user!.userId]);
    res.json({ user });
  } catch (error) {
    next(error);
  }
});

// Delete own account (self-service)
router.delete('/me', authenticate, async (req, res, next) => {
  try {
    const userId = req.user!.userId;

    // Get user phone for verification_codes cleanup
    const user = await queryOne<{ phone: string }>('SELECT phone FROM users WHERE id = $1', [userId]);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    // Clean up verification codes, then delete user (CASCADE handles the rest)
    await query('DELETE FROM verification_codes WHERE phone = $1', [user.phone]);
    await query('DELETE FROM users WHERE id = $1', [userId]);

    res.json({ message: 'Account deleted' });
  } catch (error) {
    next(error);
  }
});

export default router;

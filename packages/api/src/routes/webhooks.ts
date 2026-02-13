import { Router, raw } from 'express';
import crypto from 'crypto';
import { config } from '../config/env';
import { processPoshWebhook } from '../services/posh';

const router = Router();

// Posh webhook endpoint
router.post('/posh', raw({ type: 'application/json' }), async (req, res, next): Promise<void> => {
  try {
    // Verify webhook signature
    const signature = req.headers['x-posh-signature'] as string;

    if (!signature || !config.posh.webhookSecret) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const expectedSignature = crypto
      .createHmac('sha256', config.posh.webhookSecret)
      .update(req.body)
      .digest('hex');

    if (signature !== expectedSignature) {
      res.status(401).json({ message: 'Invalid signature' });
      return;
    }

    const payload = JSON.parse(req.body.toString());
    await processPoshWebhook(payload);

    res.json({ message: 'Webhook processed' });
  } catch (error) {
    next(error);
  }
});

export default router;

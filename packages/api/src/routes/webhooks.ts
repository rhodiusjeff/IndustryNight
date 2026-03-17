import { Router, raw } from 'express';
import crypto from 'crypto';
import { config } from '../config/env';
import { processPoshWebhook } from '../services/posh';
import { tryLogSecurityEventFromRequest } from '../services/audit';

const router = Router();

// Posh webhook endpoint
router.post('/posh', raw({ type: 'application/json' }), async (req, res, next): Promise<void> => {
  try {
    // Verify webhook signature
    const signature = req.headers['x-posh-signature'] as string;

    if (!signature || !config.posh.webhookSecret) {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'webhook',
        actorType: 'system',
        result: 'failure',
        failureReason: !signature ? 'missing_signature' : 'missing_webhook_secret',
        statusCode: 401,
        metadata: {
          source: 'posh',
        },
      });
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const expectedSignature = crypto
      .createHmac('sha256', config.posh.webhookSecret)
      .update(req.body)
      .digest('hex');

    if (signature !== expectedSignature) {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'webhook',
        actorType: 'system',
        result: 'failure',
        failureReason: 'invalid_signature',
        statusCode: 401,
        metadata: {
          source: 'posh',
        },
      });
      res.status(401).json({ message: 'Invalid signature' });
      return;
    }

    let payload: { type: string; [key: string]: unknown };
    try {
      payload = JSON.parse(req.body.toString()) as { type: string; [key: string]: unknown };
    } catch {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'webhook',
        actorType: 'system',
        result: 'failure',
        failureReason: 'malformed_payload',
        statusCode: 400,
        metadata: {
          source: 'posh',
        },
      });
      res.status(400).json({ message: 'Malformed payload' });
      return;
    }

    await processPoshWebhook(payload);

    await tryLogSecurityEventFromRequest(req, {
      action: 'verify',
      entityType: 'webhook',
      actorType: 'system',
      result: 'success',
      statusCode: 200,
      metadata: {
        source: 'posh',
      },
    });

    res.json({ message: 'Webhook processed' });
  } catch (error) {
    await tryLogSecurityEventFromRequest(req, {
      action: 'reject',
      entityType: 'webhook',
      actorType: 'system',
      result: 'failure',
      failureReason: 'webhook_processing_failed',
      statusCode: 500,
      metadata: {
        source: 'posh',
      },
    });
    next(error);
  }
});

export default router;

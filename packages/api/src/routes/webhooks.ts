import { Router, raw } from 'express';
import crypto from 'crypto';
import { config } from '../config/env';
import { processPoshWebhook } from '../services/posh';
import { tryLogSecurityEventFromRequest } from '../services/audit';

const router = Router();

function safeEquals(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

// Posh webhook endpoint
// Posh sends the shared secret as a plain header value in `Posh-Secret`.
// We also support the legacy `x-posh-signature` HMAC approach for backwards
// compatibility — if neither header is present the request is rejected.
router.post('/posh', raw({ type: 'application/json' }), async (req, res, next): Promise<void> => {
  try {
    const rawBody = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(
          typeof req.body === 'string'
            ? req.body
            : req.body
              ? JSON.stringify(req.body)
              : ''
        );

    // --- Authenticate the request ---
    const poshSecretHeader = req.headers['posh-secret'];
    const hmacSignatureHeader = req.headers['x-posh-signature'];
    const poshSecret = Array.isArray(poshSecretHeader)
      ? poshSecretHeader[0]
      : poshSecretHeader;
    const hmacSignature = Array.isArray(hmacSignatureHeader)
      ? hmacSignatureHeader[0]
      : hmacSignatureHeader;

    if (!config.posh.webhookSecret) {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'webhook',
        actorType: 'system',
        result: 'failure',
        failureReason: 'missing_webhook_secret',
        statusCode: 401,
        metadata: { source: 'posh' },
      });
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    let authenticated = false;

    // Method 1: Plain shared-secret header (Posh-Secret)
    if (poshSecret) {
      authenticated = safeEquals(poshSecret, config.posh.webhookSecret);
    }

    // Method 2: HMAC signature header (x-posh-signature) — legacy/fallback
    if (!authenticated && hmacSignature) {
      const expectedSignature = crypto
        .createHmac('sha256', config.posh.webhookSecret)
        .update(rawBody)
        .digest('hex');
      authenticated = safeEquals(hmacSignature, expectedSignature);
    }

    if (!authenticated) {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'webhook',
        actorType: 'system',
        result: 'failure',
        failureReason: !poshSecret && !hmacSignature ? 'missing_signature' : 'invalid_signature',
        statusCode: 401,
        metadata: { source: 'posh' },
      });
      res.status(401).json({ message: 'Invalid signature' });
      return;
    }

    let payload: { type: string; [key: string]: unknown };
    try {
      payload = JSON.parse(rawBody.toString()) as { type: string; [key: string]: unknown };
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

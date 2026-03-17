import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../config/auth';
import { UnauthorizedError } from '../utils/errors';
import { tryLogSecurityEventFromRequest } from '../services/audit';

function classifyTokenError(error: unknown): string {
  if (error && typeof error === 'object' && 'name' in error) {
    const name = String((error as { name?: unknown }).name);
    if (name === 'TokenExpiredError') return 'token_expired';
    if (name === 'JsonWebTokenError') return 'invalid_token';
    if (name === 'NotBeforeError') return 'token_not_active';
  }
  return 'token_validation_failed';
}

export async function authenticateAdmin(req: Request, _res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'admin_auth',
        actorType: 'system',
        result: 'failure',
        failureReason: 'missing_authorization_header',
        statusCode: 401,
      });
      throw new UnauthorizedError('Missing authorization header');
    }

    const token = authHeader.substring(7);
    const payload = verifyToken(token);

    if (payload.type !== 'access') {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'admin_auth',
        actorType: 'system',
        result: 'failure',
        failureReason: 'invalid_token_type',
        statusCode: 401,
      });
      throw new UnauthorizedError('Invalid token type');
    }

    if (payload.tokenFamily !== 'admin') {
      await tryLogSecurityEventFromRequest(req, {
        action: 'reject',
        entityType: 'admin_auth',
        actorType: 'system',
        result: 'failure',
        failureReason: 'token_family_mismatch',
        statusCode: 401,
        metadata: {
          expectedTokenFamily: 'admin',
          receivedTokenFamily: payload.tokenFamily ?? 'missing',
        },
      });
      throw new UnauthorizedError('Admin access required');
    }

    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      next(error);
      return;
    }

    await tryLogSecurityEventFromRequest(req, {
      action: 'reject',
      entityType: 'admin_auth',
      actorType: 'system',
      result: 'failure',
      failureReason: classifyTokenError(error),
      statusCode: 401,
    });
    next(new UnauthorizedError('Invalid or expired token'));
  }
}

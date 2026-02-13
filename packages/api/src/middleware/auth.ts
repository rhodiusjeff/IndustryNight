import { Request, Response, NextFunction } from 'express';
import { verifyToken, JwtPayload } from '../config/auth';
import { UnauthorizedError } from '../utils/errors';

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export function authenticate(req: Request, _res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing authorization header');
    }

    const token = authHeader.substring(7);
    const payload = verifyToken(token);

    if (payload.type !== 'access') {
      throw new UnauthorizedError('Invalid token type');
    }

    req.user = payload;
    next();
  } catch (error) {
    next(new UnauthorizedError('Invalid or expired token'));
  }
}

export function optionalAuth(req: Request, _res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const payload = verifyToken(token);
      if (payload.type === 'access') {
        req.user = payload;
      }
    }
  } catch {
    // Ignore auth errors for optional auth
  }
  next();
}

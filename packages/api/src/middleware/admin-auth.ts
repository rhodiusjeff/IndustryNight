import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../config/auth';
import { UnauthorizedError } from '../utils/errors';

export function authenticateAdmin(req: Request, _res: Response, next: NextFunction) {
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

    if (payload.tokenFamily !== 'admin') {
      throw new UnauthorizedError('Admin access required');
    }

    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      next(error);
    } else {
      next(new UnauthorizedError('Invalid or expired token'));
    }
  }
}

import { Request, Response, NextFunction } from 'express';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';

const ADMIN_ROLES = ['platformAdmin'];

export function requireAdmin(req: Request, _res: Response, next: NextFunction) {
  if (!req.user) {
    return next(new UnauthorizedError());
  }

  if (!ADMIN_ROLES.includes(req.user.role)) {
    return next(new ForbiddenError('Admin access required'));
  }

  next();
}

export function requirePlatformAdmin(req: Request, _res: Response, next: NextFunction) {
  if (!req.user) {
    return next(new UnauthorizedError());
  }

  if (req.user.role !== 'platformAdmin') {
    return next(new ForbiddenError('Platform admin access required'));
  }

  next();
}

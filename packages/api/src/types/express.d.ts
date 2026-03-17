import type { JwtPayload } from '../config/auth';

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
      requestId?: string;
    }
  }
}

export {};

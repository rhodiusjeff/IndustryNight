import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema } from 'zod';
import { BadRequestError } from '../utils/errors';
import { tryLogSecurityEventFromRequest } from '../services/audit';

export function validate(schema: ZodSchema) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const parsed = schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      // Apply parsed values (including Zod defaults/transforms) back to req
      if (parsed.body) req.body = parsed.body;
      if (parsed.query) req.query = parsed.query;
      if (parsed.params) req.params = parsed.params;
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errors: Record<string, string[]> = {};
        error.errors.forEach((err) => {
          const path = err.path.join('.');
          if (!errors[path]) errors[path] = [];
          errors[path].push(err.message);
        });

        await tryLogSecurityEventFromRequest(req, {
          action: 'reject',
          entityType: 'validation',
          actorType: req.user ? 'user' : 'system',
          actorId: req.user?.userId,
          result: 'failure',
          failureReason: 'validation_failed',
          statusCode: 400,
          metadata: {
            errorCount: error.errors.length,
            errorPaths: Object.keys(errors).slice(0, 10),
          },
        });

        next(new BadRequestError('Validation failed', errors));
      } else {
        next(error);
      }
    }
  };
}

// Common validation schemas
export const phoneSchema = z.string().regex(/^\+1\d{10}$/, 'Invalid phone number format');

export const paginationSchema = z.object({
  query: z.object({
    limit: z.coerce.number().min(1).max(100).default(20),
    offset: z.coerce.number().min(0).default(0),
  }),
});

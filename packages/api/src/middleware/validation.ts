import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema } from 'zod';
import { BadRequestError } from '../utils/errors';

export function validate(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errors: Record<string, string[]> = {};
        error.errors.forEach((err) => {
          const path = err.path.join('.');
          if (!errors[path]) errors[path] = [];
          errors[path].push(err.message);
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

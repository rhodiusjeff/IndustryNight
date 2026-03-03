import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { config } from './config/env';
import { errorHandler } from './utils/errors';
import pool, { query } from './config/database';

// Routes
import authRoutes from './routes/auth';
import usersRoutes from './routes/users';
import eventsRoutes from './routes/events';
import connectionsRoutes from './routes/connections';
import postsRoutes from './routes/posts';
import sponsorsRoutes from './routes/sponsors';
import vendorsRoutes from './routes/vendors';
import discountsRoutes from './routes/discounts';
import webhooksRoutes from './routes/webhooks';
import adminRoutes from './routes/admin';
import adminAuthRoutes from './routes/admin-auth';

const app = express();

// Middleware
app.use(helmet());
app.use(cors({
  origin: config.corsOrigins,
  credentials: true,
}));
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Skip morgan logging in test to keep output clean
if (config.nodeEnv !== 'test') {
  app.use(morgan('combined'));
}

// Rate limiters (skipped in test — tests make many requests from a single IP)
const isTest = config.nodeEnv === 'test';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
  skip: isTest ? () => true : undefined,
});

const adminAuthLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts, please try again later' },
  skip: isTest ? () => true : undefined,
});

// Health check with DB connectivity verification
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'error', message: 'Database unreachable', timestamp: new Date().toISOString() });
  }
});

// Public reference data
app.get('/specialties', async (_req, res, next) => {
  try {
    const specialties = await query(
      'SELECT id, name, category, sort_order FROM specialties WHERE is_active = true ORDER BY sort_order'
    );
    res.json({ specialties });
  } catch (err) {
    next(err);
  }
});

// API routes
app.use('/auth', authLimiter, authRoutes);
app.use('/users', usersRoutes);
app.use('/events', eventsRoutes);
app.use('/connections', connectionsRoutes);
app.use('/posts', postsRoutes);
app.use('/sponsors', sponsorsRoutes);
app.use('/vendors', vendorsRoutes);
app.use('/discounts', discountsRoutes);
app.use('/webhooks', webhooksRoutes);
app.use('/admin/auth', adminAuthLimiter, adminAuthRoutes);
app.use('/admin', adminRoutes);

// Error handling
app.use(errorHandler);

export default app;

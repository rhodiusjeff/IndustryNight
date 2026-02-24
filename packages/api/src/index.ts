import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { config } from './config/env';
import { errorHandler } from './utils/errors';
import { query } from './config/database';

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
app.use(morgan('combined'));

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
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
app.use('/auth', authRoutes);
app.use('/users', usersRoutes);
app.use('/events', eventsRoutes);
app.use('/connections', connectionsRoutes);
app.use('/posts', postsRoutes);
app.use('/sponsors', sponsorsRoutes);
app.use('/vendors', vendorsRoutes);
app.use('/discounts', discountsRoutes);
app.use('/webhooks', webhooksRoutes);
app.use('/admin', adminRoutes);

// Error handling
app.use(errorHandler);

// Start server
const PORT = config.port;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${config.nodeEnv}`);
});

export default app;

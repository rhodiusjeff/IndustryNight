/**
 * Health Endpoint Tests
 *
 * These are intentionally the simplest tests in the suite.
 * If these pass, the entire test infrastructure is working:
 *   testcontainers -> PostgreSQL -> migration -> Express app -> supertest
 *
 * If these fail, debug the infrastructure before writing more tests.
 */
import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb, getTestPool } from './helpers/db';

const app = getApp();

describe('GET /health', () => {
  it('returns 200 with status ok when database is reachable', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });

  it('includes a valid ISO timestamp', async () => {
    const res = await request(app).get('/health');

    const timestamp = new Date(res.body.timestamp);
    expect(timestamp.getTime()).not.toBeNaN();
  });
});

describe('GET /specialties', () => {
  beforeEach(async () => {
    await resetDb();
  });

  it('returns empty array when no specialties exist', async () => {
    const res = await request(app).get('/specialties');

    expect(res.status).toBe(200);
    expect(res.body.specialties).toEqual([]);
  });

  it('returns only active specialties sorted by sort_order', async () => {
    const pool = getTestPool();

    // Seed some specialties
    await pool.query(`
      INSERT INTO specialties (id, name, category, sort_order, is_active) VALUES
        ('hair', 'Hair Stylist', 'beauty', 1, true),
        ('makeup', 'Makeup Artist', 'beauty', 2, true),
        ('inactive', 'Retired Specialty', 'other', 3, false)
    `);

    const res = await request(app).get('/specialties');

    expect(res.status).toBe(200);
    expect(res.body.specialties).toHaveLength(2);
    expect(res.body.specialties[0].id).toBe('hair');
    expect(res.body.specialties[1].id).toBe('makeup');
  });
});

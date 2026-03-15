/**
 * Test App Helper
 *
 * Sets up environment variables BEFORE importing the Express app,
 * then provides a configured supertest agent.
 *
 * IMPORTANT: This module must be imported before any app code.
 * The env.ts module reads process.env at import time, so we must
 * set the test values first.
 *
 * Usage:
 *   import { getApp, closeApp } from './helpers/app';
 *
 *   afterAll(() => closeApp());
 *
 *   it('returns 200', async () => {
 *     const app = getApp();
 *     const res = await request(app).get('/health');
 *     expect(res.status).toBe(200);
 *   });
 */
import * as fs from 'fs';
import * as path from 'path';

// Read the test DB config written by setup.ts
const configPath = path.join(__dirname, '..', '.test-db-config.json');
const dbConfig = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

// Set environment variables BEFORE any app code is imported.
// These are read by config/env.ts via dotenv + Zod.
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = dbConfig.connectionString;
process.env.DB_HOST = dbConfig.host;
process.env.DB_PORT = String(dbConfig.port);
process.env.DB_NAME = dbConfig.database;
process.env.DB_USER = dbConfig.user;
process.env.DB_PASSWORD = dbConfig.password;
process.env.JWT_SECRET = 'test-jwt-secret-that-is-at-least-32-chars-long';
process.env.CORS_ORIGINS = 'http://localhost:3000';

// Now it's safe to import the app
import app from '../../src/app';
import pool from '../../src/config/database';

/** Returns the configured Express app for use with supertest */
export function getApp() {
  return app;
}

/** Close the app's database pool. Call in afterAll to avoid open handle warnings. */
export async function closeApp() {
  await pool.end();
}

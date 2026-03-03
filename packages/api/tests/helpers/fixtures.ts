/**
 * Test Fixtures
 *
 * Factory functions that INSERT test data into the database and
 * return the created records. Each function creates the minimum
 * viable record — pass overrides for non-default values.
 *
 * Usage:
 *   const user = await createUser({ name: 'Alice' });
 *   const event = await createEvent({ status: 'published' });
 *
 * These are intentionally simple factories, NOT comprehensive
 * synthetic data. The synthetic data strategy will be designed
 * in a dedicated session.
 */
import { getTestPool } from './db';
import bcrypt from 'bcryptjs';

let userCounter = 0;
let eventCounter = 0;

/** Reset counters between test suites (call in beforeEach alongside resetDb) */
export function resetFixtureCounters(): void {
  userCounter = 0;
  eventCounter = 0;
}

/** Create a social app user. Returns the full row. */
export async function createUser(overrides: Record<string, unknown> = {}) {
  userCounter++;
  const pool = getTestPool();

  const defaults = {
    phone: `+1555000${String(userCounter).padStart(4, '0')}`,
    name: `Test User ${userCounter}`,
    role: 'user',
    source: 'app',
  };

  const data = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO users (phone, name, role, source)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [data.phone, data.name, data.role, data.source]
  );

  return result.rows[0];
}

/** Create an admin user (email/password). Returns the full row. */
export async function createAdminUser(overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    email: `admin${++userCounter}@test.com`,
    name: 'Test Admin',
    password: 'testpassword123',
    role: 'platformAdmin',
  };

  const data = { ...defaults, ...overrides };

  const passwordHash = await bcrypt.hash(data.password as string, 10);

  const result = await pool.query(
    `INSERT INTO admin_users (email, password_hash, name, role)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [data.email, passwordHash, data.name, data.role]
  );

  // Attach the plain password for test convenience
  return { ...result.rows[0], _password: data.password };
}

/** Create an event. Returns the full row. */
export async function createEvent(overrides: Record<string, unknown> = {}) {
  eventCounter++;
  const pool = getTestPool();

  const defaults = {
    name: `Test Event ${eventCounter}`,
    venue_name: 'Test Venue',
    venue_address: '123 Test St',
    start_time: new Date(Date.now() + 86400000).toISOString(), // tomorrow
    end_time: new Date(Date.now() + 90000000).toISOString(),   // tomorrow + 1hr
    status: 'draft',
    activation_code: '1234',
  };

  const data = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO events (name, venue_name, venue_address, start_time, end_time, status, activation_code)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [data.name, data.venue_name, data.venue_address, data.start_time, data.end_time, data.status, data.activation_code]
  );

  return result.rows[0];
}

/** Create a sponsor. Returns the full row. */
export async function createSponsor(overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    name: `Test Sponsor ${++eventCounter}`,
    tier: 'bronze',
  };

  const data = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO sponsors (name, tier) VALUES ($1, $2) RETURNING *`,
    [data.name, data.tier]
  );

  return result.rows[0];
}

/** Create a post. Requires an author (user). Returns the full row. */
export async function createPost(authorId: string, overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    content: 'Test post content',
    type: 'general',
  };

  const data = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO posts (author_id, content, type)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [authorId, data.content, data.type]
  );

  return result.rows[0];
}

/** Create a ticket for a user at an event. Returns the full row. */
export async function createTicket(userId: string, eventId: string, overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    ticket_type: 'general',
    price: 0,
    status: 'purchased',
    purchased_at: new Date().toISOString(),
  };

  const data = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO tickets (user_id, event_id, ticket_type, price, status, purchased_at)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, eventId, data.ticket_type, data.price, data.status, data.purchased_at]
  );

  return result.rows[0];
}

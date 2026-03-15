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
let customerCounter = 0;
let productCounter = 0;
let marketCounter = 0;

/** Reset counters between test suites (call in beforeEach alongside resetDb) */
export function resetFixtureCounters(): void {
  userCounter = 0;
  eventCounter = 0;
  customerCounter = 0;
  productCounter = 0;
  marketCounter = 0;
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
    posh_event_id: null as string | null,
    market_id: null as string | null,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO events (name, venue_name, venue_address, start_time, end_time, status, activation_code, posh_event_id, market_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [data.name, data.venue_name, data.venue_address, data.start_time, data.end_time, data.status, data.activation_code, data.posh_event_id, data.market_id]
  );

  return result.rows[0];
}

/** Create a market. Returns the full row. */
export async function createMarket(overrides: Record<string, unknown> = {}) {
  marketCounter++;
  const pool = getTestPool();

  const name = (overrides.name as string) || `Test Market ${marketCounter}`;
  const slug = (overrides.slug as string) || name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

  const defaults = {
    name,
    slug,
    is_active: true,
    sort_order: 0,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO markets (name, slug, description, timezone, is_active, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [data.name, data.slug || slug, data.description || null, data.timezone || null,
     data.is_active, data.sort_order]
  );

  return result.rows[0];
}

/** Create a customer (replaces createSponsor). Returns the full row. */
export async function createCustomer(overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    name: `Test Customer ${++customerCounter}`,
    is_active: true,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO customers (name, description, website, logo_url, contact_email, contact_phone, is_active, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [data.name, data.description || null, data.website || null, data.logo_url || null,
     data.contact_email || null, data.contact_phone || null, data.is_active, data.notes || null]
  );

  return result.rows[0];
}

/** Create a product catalog entry. Returns the full row. */
export async function createProduct(overrides: Record<string, unknown> = {}) {
  const pool = getTestPool();

  const defaults = {
    name: `Test Product ${++productCounter}`,
    product_type: 'sponsorship',
    is_standard: true,
    is_active: true,
    config: '{}',
    sort_order: 0,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO products (name, product_type, description, base_price_cents, is_standard, config, is_active, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
     RETURNING *`,
    [data.name, data.product_type, data.description || null, data.base_price_cents || null,
     data.is_standard, typeof data.config === 'string' ? data.config : JSON.stringify(data.config),
     data.is_active, data.sort_order]
  );

  return result.rows[0];
}

/** Create a customer_product (a purchase). Returns the full row. */
export async function createCustomerProduct(
  customerId: string,
  productId: string,
  overrides: Record<string, unknown> = {}
) {
  const pool = getTestPool();

  const defaults = {
    status: 'active',
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, status, start_date, end_date, config_overrides, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9)
     RETURNING *`,
    [customerId, productId, data.event_id || null, data.price_paid_cents || null,
     data.status, data.start_date || null, data.end_date || null,
     data.config_overrides ? JSON.stringify(data.config_overrides) : '{}',
     data.notes || null]
  );

  return result.rows[0];
}

/** Create a discount for a customer. Returns the full row. */
export async function createDiscount(
  customerId: string,
  overrides: Record<string, unknown> = {}
) {
  const pool = getTestPool();

  const defaults = {
    title: `Test Discount ${++productCounter}`,
    type: 'percentage',
    value: 10,
    is_active: true,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO discounts (customer_id, title, description, type, value, code, terms, is_active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [customerId, data.title, data.description || null, data.type,
     data.value, data.code || null, data.terms || null, data.is_active]
  );

  return result.rows[0];
}

/** Create a customer contact. Returns the full row. */
export async function createContact(
  customerId: string,
  overrides: Record<string, unknown> = {}
) {
  const pool = getTestPool();

  const defaults = {
    name: `Contact ${++customerCounter}`,
    role: 'other',
    is_primary: false,
  };

  const data: any = { ...defaults, ...overrides };

  const result = await pool.query(
    `INSERT INTO customer_contacts (customer_id, name, email, phone, role, title, is_primary, notes)
     VALUES ($1, $2, $3, $4, $5::contact_role, $6, $7, $8)
     RETURNING *`,
    [customerId, data.name, data.email || null, data.phone || null,
     data.role, data.title || null, data.is_primary, data.notes || null]
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

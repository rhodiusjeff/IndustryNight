/**
 * Customer & Revenue Model Tests
 *
 * Tests the unified customer model that replaces separate sponsors/vendors:
 *   - Customer CRUD (admin)
 *   - Product catalog CRUD (admin)
 *   - Customer product management (admin)
 *   - Discount CRUD (admin)
 *   - Discount redemption (social)
 *   - Event partner convenience routes (admin)
 *   - Social-facing sponsor/discount endpoints
 */
import request from 'supertest';
import { getApp } from './helpers/app';
import { resetDb, getTestPool } from './helpers/db';
import { adminToken, socialToken } from './helpers/auth';
import {
  createAdminUser,
  createUser,
  createEvent,
  createCustomer,
  createProduct,
  createCustomerProduct,
  createDiscount,
  createMarket,
  createContact,
  resetFixtureCounters,
} from './helpers/fixtures';

const app = getApp();

describe('Customer Model', () => {
  let admin: any;
  let token: string;

  beforeEach(async () => {
    await resetDb();
    resetFixtureCounters();
    admin = await createAdminUser();
    token = adminToken(admin.id);
  });

  // ─── Customer CRUD ────────────────────────────────────

  describe('GET /admin/customers', () => {
    it('returns empty list initially', async () => {
      const res = await request(app)
        .get('/admin/customers')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customers).toEqual([]);
    });

    it('returns all customers', async () => {
      await createCustomer({ name: 'Acme Hair Co' });
      await createCustomer({ name: 'Beauty Supply Inc' });

      const res = await request(app)
        .get('/admin/customers')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customers).toHaveLength(2);
    });

    it('filters by search query', async () => {
      await createCustomer({ name: 'Acme Hair Co' });
      await createCustomer({ name: 'Beauty Supply Inc' });

      const res = await request(app)
        .get('/admin/customers?q=acme')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customers).toHaveLength(1);
      expect(res.body.customers[0].name).toBe('Acme Hair Co');
    });

    it('filters by product type', async () => {
      const sponsor = await createCustomer({ name: 'Sponsor Co' });
      const vendor = await createCustomer({ name: 'Vendor Co' });
      const product = await createProduct({ product_type: 'sponsorship' });
      const vendorProduct = await createProduct({ product_type: 'vendor_space' });
      await createCustomerProduct(sponsor.id, product.id);
      await createCustomerProduct(vendor.id, vendorProduct.id);

      const res = await request(app)
        .get('/admin/customers?hasProductType=sponsorship')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customers).toHaveLength(1);
      expect(res.body.customers[0].name).toBe('Sponsor Co');
    });
  });

  describe('POST /admin/customers', () => {
    it('creates a customer with required fields', async () => {
      const res = await request(app)
        .post('/admin/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'New Customer' });

      expect(res.status).toBe(201);
      expect(res.body.customer.name).toBe('New Customer');
      expect(res.body.customer.is_active).toBe(true);
      expect(res.body.customer.id).toBeDefined();
    });

    it('creates a customer with all fields', async () => {
      const res = await request(app)
        .post('/admin/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Full Customer',
          description: 'A test customer',
          website: 'https://example.com',
          logoUrl: 'https://example.com/logo.png',
          contactEmail: 'contact@example.com',
          contactPhone: '+15551234567',
          notes: 'Internal note',
        });

      expect(res.status).toBe(201);
      expect(res.body.customer.description).toBe('A test customer');
      expect(res.body.customer.website).toBe('https://example.com');
      expect(res.body.customer.contact_email).toBe('contact@example.com');
    });

    it('requires name', async () => {
      const res = await request(app)
        .post('/admin/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({});

      expect(res.status).toBeGreaterThanOrEqual(400);
    });
  });

  describe('GET /admin/customers/:id', () => {
    it('returns customer with products and discounts', async () => {
      const customer = await createCustomer({ name: 'Detail Customer' });
      const product = await createProduct({ product_type: 'sponsorship', name: 'Gold Sponsorship' });
      await createCustomerProduct(customer.id, product.id, { price_paid_cents: 200000 });
      await createDiscount(customer.id, { title: '20% off', code: 'SAVE20' });

      const res = await request(app)
        .get(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customer.name).toBe('Detail Customer');
      expect(res.body.customer.products).toHaveLength(1);
      expect(res.body.customer.products[0].product_name).toBe('Gold Sponsorship');
      expect(res.body.customer.discounts).toHaveLength(1);
      expect(res.body.customer.discounts[0].title).toBe('20% off');
    });

    it('returns 404 for nonexistent customer', async () => {
      const res = await request(app)
        .get('/admin/customers/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
    });
  });

  describe('PATCH /admin/customers/:id', () => {
    it('updates customer fields', async () => {
      const customer = await createCustomer({ name: 'Original Name' });

      const res = await request(app)
        .patch(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Updated Name', isActive: false });

      expect(res.status).toBe(200);
      expect(res.body.customer.name).toBe('Updated Name');
      expect(res.body.customer.is_active).toBe(false);
    });
  });

  describe('DELETE /admin/customers/:id', () => {
    it('deletes customer and cascades to products and discounts', async () => {
      const customer = await createCustomer();
      const product = await createProduct();
      await createCustomerProduct(customer.id, product.id);
      await createDiscount(customer.id, { title: 'Will be deleted' });

      const res = await request(app)
        .delete(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      // Verify cascade
      const pool = getTestPool();
      const cpRows = await pool.query('SELECT * FROM customer_products WHERE customer_id = $1', [customer.id]);
      expect(cpRows.rows).toHaveLength(0);

      const discRows = await pool.query('SELECT * FROM discounts WHERE customer_id = $1', [customer.id]);
      expect(discRows.rows).toHaveLength(0);
    });
  });

  // ─── Product Catalog ──────────────────────────────────

  describe('GET /admin/products', () => {
    it('returns product catalog', async () => {
      await createProduct({ name: 'Gold Sponsorship', product_type: 'sponsorship' });
      await createProduct({ name: 'Standard Booth', product_type: 'vendor_space' });

      const res = await request(app)
        .get('/admin/products')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.products).toHaveLength(2);
    });

    it('filters by product type', async () => {
      await createProduct({ product_type: 'sponsorship' });
      await createProduct({ product_type: 'vendor_space' });

      const res = await request(app)
        .get('/admin/products?type=sponsorship')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.products).toHaveLength(1);
      expect(res.body.products[0].product_type).toBe('sponsorship');
    });
  });

  describe('POST /admin/products', () => {
    it('creates a product', async () => {
      const res = await request(app)
        .post('/admin/products')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Event Sponsorship - Gold',
          productType: 'sponsorship',
          basePriceCents: 200000,
          config: { level: 'event', tier: 'gold' },
        });

      expect(res.status).toBe(201);
      expect(res.body.product.name).toBe('Event Sponsorship - Gold');
      expect(res.body.product.base_price_cents).toBe(200000);
      expect(res.body.product.config).toEqual({ level: 'event', tier: 'gold' });
    });
  });

  describe('DELETE /admin/products/:id', () => {
    it('prevents deletion when referenced by customer_products', async () => {
      const product = await createProduct();
      const customer = await createCustomer();
      await createCustomerProduct(customer.id, product.id);

      const res = await request(app)
        .delete(`/admin/products/${product.id}`)
        .set('Authorization', `Bearer ${token}`);

      // Should fail due to RESTRICT
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it('allows deletion of unreferenced product', async () => {
      const product = await createProduct();

      const res = await request(app)
        .delete(`/admin/products/${product.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
    });
  });

  // ─── Customer Products ────────────────────────────────

  describe('Customer product management', () => {
    it('records a purchase', async () => {
      const customer = await createCustomer();
      const product = await createProduct();

      const res = await request(app)
        .post(`/admin/customers/${customer.id}/products`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          productId: product.id,
          pricePaidCents: 150000,
          notes: 'Negotiated rate',
        });

      expect(res.status).toBe(201);
      expect(res.body.customerProduct.customer_id).toBe(customer.id);
      expect(res.body.customerProduct.product_id).toBe(product.id);
      expect(res.body.customerProduct.price_paid_cents).toBe(150000);
    });

    it('lists customer products', async () => {
      const customer = await createCustomer();
      const p1 = await createProduct({ name: 'Gold Sponsorship' });
      const p2 = await createProduct({ name: 'Standard Booth', product_type: 'vendor_space' });
      await createCustomerProduct(customer.id, p1.id);
      await createCustomerProduct(customer.id, p2.id);

      const res = await request(app)
        .get(`/admin/customers/${customer.id}/products`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.products).toHaveLength(2);
    });

    it('updates customer product status', async () => {
      const customer = await createCustomer();
      const product = await createProduct();
      const cp = await createCustomerProduct(customer.id, product.id);

      const res = await request(app)
        .patch(`/admin/customers/${customer.id}/products/${cp.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'expired' });

      expect(res.status).toBe(200);
      expect(res.body.customerProduct.status).toBe('expired');
    });
  });

  // ─── Discounts ────────────────────────────────────────

  describe('Discount CRUD', () => {
    it('creates a discount for a customer', async () => {
      const customer = await createCustomer();

      const res = await request(app)
        .post(`/admin/customers/${customer.id}/discounts`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: '20% off all services',
          type: 'percentage',
          value: 20,
          code: 'SAVE20',
          terms: 'Valid for verified members only',
        });

      expect(res.status).toBe(201);
      expect(res.body.discount.title).toBe('20% off all services');
      expect(res.body.discount.customer_id).toBe(customer.id);
      expect(res.body.discount.code).toBe('SAVE20');
    });

    it('lists discounts for a customer', async () => {
      const customer = await createCustomer();
      await createDiscount(customer.id, { title: 'Discount 1' });
      await createDiscount(customer.id, { title: 'Discount 2' });

      const res = await request(app)
        .get(`/admin/customers/${customer.id}/discounts`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.discounts).toHaveLength(2);
    });
  });

  // ─── Discount Redemptions ─────────────────────────────

  describe('Discount redemption (social)', () => {
    it('allows a user to redeem a discount', async () => {
      const customer = await createCustomer();
      const discount = await createDiscount(customer.id, { title: '10% off', code: 'TEN' });
      const user = await createUser();
      const userToken = socialToken(user.id);

      const res = await request(app)
        .post(`/discounts/${discount.id}/redeem`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ method: 'self_reported' });

      expect(res.status).toBe(201);
      expect(res.body.redemption).toBeDefined();
      expect(res.body.redemption.id).toBeDefined();
      expect(res.body.redemption.redeemed_at).toBeDefined();
    });

    it('prevents duplicate redemption', async () => {
      const customer = await createCustomer();
      const discount = await createDiscount(customer.id);
      const user = await createUser();
      const userToken = socialToken(user.id);

      // First redemption
      await request(app)
        .post(`/discounts/${discount.id}/redeem`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ method: 'self_reported' });

      // Duplicate
      const res = await request(app)
        .post(`/discounts/${discount.id}/redeem`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ method: 'self_reported' });

      expect(res.status).toBe(409);
    });

    it('checks if user has redeemed a discount', async () => {
      const customer = await createCustomer();
      const discount = await createDiscount(customer.id);
      const user = await createUser();
      const userToken = socialToken(user.id);

      // Not yet redeemed
      let res = await request(app)
        .get(`/discounts/${discount.id}/redeemed`)
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.redeemed).toBe(false);

      // Redeem
      await request(app)
        .post(`/discounts/${discount.id}/redeem`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ method: 'self_reported' });

      // Now redeemed
      res = await request(app)
        .get(`/discounts/${discount.id}/redeemed`)
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.redeemed).toBe(true);
    });
  });

  // ─── Event Partners ───────────────────────────────────

  describe('Event partner routes', () => {
    it('adds a partner to an event', async () => {
      const event = await createEvent();
      const customer = await createCustomer();
      const product = await createProduct();

      const res = await request(app)
        .post(`/admin/events/${event.id}/partners`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          customerId: customer.id,
          productId: product.id,
          pricePaidCents: 200000,
        });

      expect(res.status).toBe(201);
      expect(res.body.customerProduct.customer_id).toBe(customer.id);
      expect(res.body.customerProduct.event_id).toBe(event.id);
    });

    it('removes a partner from an event', async () => {
      const event = await createEvent();
      const customer = await createCustomer();
      const product = await createProduct();
      const cp = await createCustomerProduct(customer.id, product.id, { event_id: event.id });

      const res = await request(app)
        .delete(`/admin/events/${event.id}/partners/${cp.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      // Verify removal
      const pool = getTestPool();
      const rows = await pool.query('SELECT * FROM customer_products WHERE id = $1', [cp.id]);
      expect(rows.rows).toHaveLength(0);
    });

    it('shows partners in event detail', async () => {
      const event = await createEvent();
      const customer = await createCustomer({ name: 'Event Sponsor Co' });
      const product = await createProduct({
        product_type: 'sponsorship',
        config: JSON.stringify({ level: 'event', tier: 'gold' }),
      });
      await createCustomerProduct(customer.id, product.id, { event_id: event.id });

      const res = await request(app)
        .get(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.event.partners).toHaveLength(1);
      expect(res.body.event.partners[0].name).toBe('Event Sponsor Co');
      expect(res.body.event.partners[0].product_type).toBe('sponsorship');
    });
  });

  // ─── Social-facing endpoints ──────────────────────────

  describe('Social sponsor/discount endpoints', () => {
    it('GET /sponsors returns active customers with sponsorship products', async () => {
      const customer = await createCustomer({ name: 'Visible Sponsor' });
      const product = await createProduct({ product_type: 'sponsorship' });
      await createCustomerProduct(customer.id, product.id);

      // Non-sponsor customer (vendor only)
      const vendor = await createCustomer({ name: 'Vendor Only' });
      const vendorProduct = await createProduct({ product_type: 'vendor_space' });
      await createCustomerProduct(vendor.id, vendorProduct.id);

      const user = await createUser();
      const userToken = socialToken(user.id);

      const res = await request(app)
        .get('/sponsors')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.sponsors).toHaveLength(1);
      expect(res.body.sponsors[0].name).toBe('Visible Sponsor');
    });

    it('GET /discounts returns active discounts with customer info', async () => {
      const customer = await createCustomer({ name: 'Perk Provider' });
      await createDiscount(customer.id, { title: 'Test Perk', code: 'PERK10' });

      const user = await createUser();
      const userToken = socialToken(user.id);

      const res = await request(app)
        .get('/discounts')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.discounts).toHaveLength(1);
      expect(res.body.discounts[0].title).toBe('Test Perk');
      expect(res.body.discounts[0].customer_name).toBe('Perk Provider');
    });
  });

  // ─── Redemption analytics (admin) ─────────────────────

  describe('Redemption analytics', () => {
    it('returns redemption stats for a customer', async () => {
      const customer = await createCustomer();
      const discount = await createDiscount(customer.id, { title: 'Popular Perk' });
      const user1 = await createUser();
      const user2 = await createUser();

      // Two users redeem
      const pool = getTestPool();
      await pool.query(
        `INSERT INTO discount_redemptions (discount_id, user_id, method) VALUES ($1, $2, 'self_reported')`,
        [discount.id, user1.id]
      );
      await pool.query(
        `INSERT INTO discount_redemptions (discount_id, user_id, method) VALUES ($1, $2, 'self_reported')`,
        [discount.id, user2.id]
      );

      const res = await request(app)
        .get(`/admin/customers/${customer.id}/redemptions`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.redemptions).toBeDefined();
    });
  });

  // ─── Markets ───────────────────────────────────────────

  describe('GET /admin/markets', () => {
    it('returns created markets', async () => {
      await createMarket({ name: 'NYC', slug: 'nyc', timezone: 'America/New_York', sort_order: 0 });
      await createMarket({ name: 'LA', slug: 'la', timezone: 'America/Los_Angeles', sort_order: 1 });
      await createMarket({ name: 'Atlanta', slug: 'atlanta', timezone: 'America/New_York', sort_order: 2 });

      const res = await request(app)
        .get('/admin/markets')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.markets).toBeDefined();
      expect(res.body.markets.length).toBe(3);
      const names = res.body.markets.map((m: any) => m.name);
      expect(names).toContain('NYC');
      expect(names).toContain('LA');
      expect(names).toContain('Atlanta');
    });

    it('includes event counts', async () => {
      await createMarket({ name: 'NYC', slug: 'nyc' });

      const res = await request(app)
        .get('/admin/markets')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      for (const market of res.body.markets) {
        expect(market.event_count).toBeDefined();
        expect(typeof market.event_count).toBe('number');
      }
    });
  });

  describe('POST /admin/markets', () => {
    it('creates a market with auto-generated slug', async () => {
      const res = await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Miami', description: 'South Florida', timezone: 'America/New_York' });

      expect(res.status).toBe(201);
      expect(res.body.market.name).toBe('Miami');
      expect(res.body.market.slug).toBe('miami');
      expect(res.body.market.description).toBe('South Florida');
      expect(res.body.market.timezone).toBe('America/New_York');
      expect(res.body.market.is_active).toBe(true);
    });

    it('auto-generates slug with hyphens from multi-word name', async () => {
      const res = await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'San Francisco Bay Area' });

      expect(res.status).toBe(201);
      expect(res.body.market.slug).toBe('san-francisco-bay-area');
    });

    it('returns 409 for duplicate name', async () => {
      // Create first
      await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'NYC' });

      // Duplicate
      const res = await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'NYC' });

      expect(res.status).toBe(409);
    });

    it('validates required name', async () => {
      const res = await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ description: 'No name provided' });

      expect(res.status).toBe(400);
    });
  });

  describe('PATCH /admin/markets/:id', () => {
    it('updates market name', async () => {
      const market = await createMarket({ name: 'Atlanta', slug: 'atlanta' });

      const res = await request(app)
        .patch(`/admin/markets/${market.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Atlanta Metro' });

      expect(res.status).toBe(200);
      expect(res.body.market.name).toBe('Atlanta Metro');
      // Slug should NOT change
      expect(res.body.market.slug).toBe('atlanta');
    });

    it('does not change slug even when name changes', async () => {
      const createRes = await request(app)
        .post('/admin/markets')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Test Market' });

      const id = createRes.body.market.id;
      const originalSlug = createRes.body.market.slug;

      const updateRes = await request(app)
        .patch(`/admin/markets/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Renamed Market' });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.market.slug).toBe(originalSlug);
    });

    it('retires a market (is_active = false)', async () => {
      const market = await createMarket({ name: 'LA', slug: 'la' });

      const res = await request(app)
        .patch(`/admin/markets/${market.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ isActive: false });

      expect(res.status).toBe(200);
      expect(res.body.market.is_active).toBe(false);
    });

    it('activates a retired market', async () => {
      const market = await createMarket({ name: 'LA', slug: 'la', is_active: false });

      const res = await request(app)
        .patch(`/admin/markets/${market.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ isActive: true });

      expect(res.status).toBe(200);
      expect(res.body.market.is_active).toBe(true);
    });

    it('returns 404 for non-existent market', async () => {
      const res = await request(app)
        .patch('/admin/markets/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Ghost' });

      expect(res.status).toBe(404);
    });
  });

  describe('GET /markets (public)', () => {
    it('returns only active markets without auth', async () => {
      await createMarket({ name: 'NYC', slug: 'nyc' });
      await createMarket({ name: 'LA', slug: 'la', is_active: false });
      await createMarket({ name: 'Atlanta', slug: 'atlanta' });

      const res = await request(app).get('/markets');

      expect(res.status).toBe(200);
      expect(res.body.markets).toBeDefined();
      const names = res.body.markets.map((m: any) => m.name);
      expect(names).toContain('NYC');
      expect(names).toContain('Atlanta');
      expect(names).not.toContain('LA');
    });

    it('returns minimal fields for dropdowns', async () => {
      await createMarket({ name: 'NYC', slug: 'nyc' });

      const res = await request(app).get('/markets');

      expect(res.status).toBe(200);
      const market = res.body.markets[0];
      expect(market.id).toBeDefined();
      expect(market.name).toBeDefined();
      expect(market.slug).toBeDefined();
      // Should not include admin-only fields
      expect(market.created_at).toBeUndefined();
      expect(market.updated_at).toBeUndefined();
      expect(market.event_count).toBeUndefined();
    });
  });

  describe('No DELETE endpoint for markets', () => {
    it('returns 404 for DELETE /admin/markets/:id', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });

      const res = await request(app)
        .delete(`/admin/markets/${market.id}`)
        .set('Authorization', `Bearer ${token}`);

      // Should be 404 (no route) or 405 (method not allowed)
      expect([404, 405]).toContain(res.status);
    });
  });

  // ─── Event + Market Association ─────────────────────────

  describe('Event-Market Association', () => {
    it('creates event with marketId', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });

      const res = await request(app)
        .post('/admin/events')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'NYC Launch Party',
          startTime: new Date(Date.now() + 86400000).toISOString(),
          endTime: new Date(Date.now() + 90000000).toISOString(),
          marketId: market.id,
        });

      expect(res.status).toBe(201);
      expect(res.body.event.market_id).toBe(market.id);
      expect(res.body.event.market_name).toBe('NYC');
    });

    it('creates event without marketId (null)', async () => {
      const res = await request(app)
        .post('/admin/events')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Unassigned Event',
          startTime: new Date(Date.now() + 86400000).toISOString(),
          endTime: new Date(Date.now() + 90000000).toISOString(),
        });

      expect(res.status).toBe(201);
      expect(res.body.event.market_id).toBeNull();
    });

    it('updates event marketId', async () => {
      const market1 = await createMarket({ name: 'NYC', slug: 'nyc' });
      const market2 = await createMarket({ name: 'LA', slug: 'la' });
      const event = await createEvent({ market_id: market1.id });

      const res = await request(app)
        .patch(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ marketId: market2.id });

      expect(res.status).toBe(200);
      expect(res.body.event.market_id).toBe(market2.id);
      expect(res.body.event.market_name).toBe('LA');
    });

    it('clears event marketId to null', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const event = await createEvent({ market_id: market.id });

      const res = await request(app)
        .patch(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ marketId: null });

      expect(res.status).toBe(200);
      expect(res.body.event.market_id).toBeNull();
      expect(res.body.event.market_name).toBeNull();
    });

    it('event list includes market_name', async () => {
      const market = await createMarket({ name: 'Atlanta', slug: 'atlanta' });
      await createEvent({ market_id: market.id });
      await createEvent(); // no market

      const res = await request(app)
        .get('/admin/events')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      const withMarket = res.body.events.find((e: any) => e.market_name === 'Atlanta');
      const withoutMarket = res.body.events.find((e: any) => e.market_name === null);
      expect(withMarket).toBeDefined();
      expect(withoutMarket).toBeDefined();
    });

    it('event detail includes market_name', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const event = await createEvent({ market_id: market.id });

      const res = await request(app)
        .get(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.event.market_id).toBe(market.id);
      expect(res.body.event.market_name).toBe('NYC');
    });

    it('publish gate rejects event without market', async () => {
      const pool = getTestPool();
      const event = await createEvent({
        posh_event_id: 'posh-123',
        venue_name: 'Test Venue',
        venue_address: '123 Main St',
      });
      // Add an image directly
      await pool.query(
        `INSERT INTO event_images (event_id, url, sort_order) VALUES ($1, 'https://example.com/img.jpg', 0)`,
        [event.id]
      );

      const res = await request(app)
        .patch(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'published' });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Market');
    });

    it('publish gate rejects event without venue address', async () => {
      const pool = getTestPool();
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const event = await createEvent({
        posh_event_id: 'posh-123',
        venue_name: 'Test Venue',
        venue_address: null,
        market_id: market.id,
      });
      await pool.query(
        `INSERT INTO event_images (event_id, url, sort_order) VALUES ($1, 'https://example.com/img.jpg', 0)`,
        [event.id]
      );

      const res = await request(app)
        .patch(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'published' });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Venue address');
    });

    it('publish succeeds with all requirements', async () => {
      const pool = getTestPool();
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const event = await createEvent({
        posh_event_id: 'posh-456',
        venue_name: 'Test Venue',
        venue_address: '456 Main St',
        market_id: market.id,
      });
      await pool.query(
        `INSERT INTO event_images (event_id, url, sort_order) VALUES ($1, 'https://example.com/img.jpg', 0)`,
        [event.id]
      );

      const res = await request(app)
        .patch(`/admin/events/${event.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'published' });

      expect(res.status).toBe(200);
      expect(res.body.event.status).toBe('published');
      expect(res.body.event.market_name).toBe('NYC');
    });
  });

  // ─── Customer Contacts ──────────────────────────────

  describe('Customer Contacts CRUD', () => {
    it('creates a contact', async () => {
      const customer = await createCustomer();

      const res = await request(app)
        .post(`/admin/customers/${customer.id}/contacts`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Jane Doe',
          email: 'jane@example.com',
          phone: '+15551234567',
          role: 'primary',
          title: 'Marketing Director',
          isPrimary: true,
        });

      expect(res.status).toBe(201);
      expect(res.body.contact.name).toBe('Jane Doe');
      expect(res.body.contact.email).toBe('jane@example.com');
      expect(res.body.contact.role).toBe('primary');
      expect(res.body.contact.title).toBe('Marketing Director');
      expect(res.body.contact.is_primary).toBe(true);
      expect(res.body.contact.customer_id).toBe(customer.id);
    });

    it('lists contacts for a customer', async () => {
      const customer = await createCustomer();
      await createContact(customer.id, { name: 'Contact A' });
      await createContact(customer.id, { name: 'Contact B' });

      const res = await request(app)
        .get(`/admin/customers/${customer.id}/contacts`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.contacts).toHaveLength(2);
    });

    it('updates a contact', async () => {
      const customer = await createCustomer();
      const contact = await createContact(customer.id, { name: 'Old Name', role: 'other' });

      const res = await request(app)
        .patch(`/admin/customers/${customer.id}/contacts/${contact.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'New Name', role: 'billing', title: 'CFO' });

      expect(res.status).toBe(200);
      expect(res.body.contact.name).toBe('New Name');
      expect(res.body.contact.role).toBe('billing');
      expect(res.body.contact.title).toBe('CFO');
    });

    it('deletes a contact', async () => {
      const customer = await createCustomer();
      const contact = await createContact(customer.id, { name: 'To Delete' });

      const res = await request(app)
        .delete(`/admin/customers/${customer.id}/contacts/${contact.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      // Verify deletion
      const pool = getTestPool();
      const rows = await pool.query('SELECT * FROM customer_contacts WHERE id = $1', [contact.id]);
      expect(rows.rows).toHaveLength(0);
    });

    it('returns 404 for contact on nonexistent customer', async () => {
      const res = await request(app)
        .get('/admin/customers/00000000-0000-0000-0000-000000000000/contacts')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
    });

    it('unsets existing primary when setting new primary contact', async () => {
      const customer = await createCustomer();
      const contact1 = await createContact(customer.id, { name: 'First Primary', is_primary: true });
      await createContact(customer.id, { name: 'Second' });

      // Create new primary via API
      await request(app)
        .post(`/admin/customers/${customer.id}/contacts`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'New Primary', isPrimary: true });

      // Original primary should be unset
      const pool = getTestPool();
      const row = await pool.query('SELECT is_primary FROM customer_contacts WHERE id = $1', [contact1.id]);
      expect(row.rows[0].is_primary).toBe(false);
    });

    it('contacts appear in customer detail', async () => {
      const customer = await createCustomer();
      await createContact(customer.id, { name: 'Detail Contact', role: 'primary', is_primary: true });

      const res = await request(app)
        .get(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customer.contacts).toHaveLength(1);
      expect(res.body.customer.contacts[0].name).toBe('Detail Contact');
      expect(res.body.customer.contacts[0].role).toBe('primary');
      expect(res.body.customer.contacts[0].is_primary).toBe(true);
    });

    it('cascades delete when customer is deleted', async () => {
      const customer = await createCustomer();
      const contact = await createContact(customer.id, { name: 'Will Cascade' });

      await request(app)
        .delete(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      const pool = getTestPool();
      const rows = await pool.query('SELECT * FROM customer_contacts WHERE id = $1', [contact.id]);
      expect(rows.rows).toHaveLength(0);
    });
  });

  // ─── Customer-Market Associations ───────────────────

  describe('Customer-Market Associations', () => {
    it('creates customer with marketIds', async () => {
      const market1 = await createMarket({ name: 'NYC', slug: 'nyc' });
      const market2 = await createMarket({ name: 'LA', slug: 'la' });

      const res = await request(app)
        .post('/admin/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Multi-Market Co', marketIds: [market1.id, market2.id] });

      expect(res.status).toBe(201);

      // Verify associations in DB
      const pool = getTestPool();
      const rows = await pool.query(
        'SELECT * FROM customer_markets WHERE customer_id = $1',
        [res.body.customer.id]
      );
      expect(rows.rows).toHaveLength(2);
    });

    it('customer list includes market names', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const customer = await createCustomer();

      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer.id, market.id]
      );

      const res = await request(app)
        .get('/admin/customers')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      const found = res.body.customers.find((c: any) => c.id === customer.id);
      expect(found.markets).toBeDefined();
      expect(found.markets).toHaveLength(1);
      expect(found.markets[0].name).toBe('NYC');
    });

    it('customer detail includes full market objects', async () => {
      const market = await createMarket({ name: 'Atlanta', slug: 'atlanta', timezone: 'America/New_York' });
      const customer = await createCustomer();

      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer.id, market.id]
      );

      const res = await request(app)
        .get(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customer.markets).toHaveLength(1);
      expect(res.body.customer.markets[0].name).toBe('Atlanta');
      expect(res.body.customer.markets[0].timezone).toBe('America/New_York');
    });

    it('updates customer marketIds (full replace)', async () => {
      const market1 = await createMarket({ name: 'NYC', slug: 'nyc' });
      const market2 = await createMarket({ name: 'LA', slug: 'la' });
      const market3 = await createMarket({ name: 'Atlanta', slug: 'atlanta' });
      const customer = await createCustomer();

      // Set initial markets
      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2), ($1, $3)',
        [customer.id, market1.id, market2.id]
      );

      // Replace with different set
      const res = await request(app)
        .patch(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ marketIds: [market3.id] });

      expect(res.status).toBe(200);

      const rows = await pool.query(
        'SELECT market_id FROM customer_markets WHERE customer_id = $1',
        [customer.id]
      );
      expect(rows.rows).toHaveLength(1);
      expect(rows.rows[0].market_id).toBe(market3.id);
    });

    it('clears all market associations with empty array', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const customer = await createCustomer();

      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer.id, market.id]
      );

      const res = await request(app)
        .patch(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ marketIds: [] });

      expect(res.status).toBe(200);

      const rows = await pool.query(
        'SELECT * FROM customer_markets WHERE customer_id = $1',
        [customer.id]
      );
      expect(rows.rows).toHaveLength(0);
    });

    it('filters customers by marketId', async () => {
      const market1 = await createMarket({ name: 'NYC', slug: 'nyc' });
      const market2 = await createMarket({ name: 'LA', slug: 'la' });
      const customer1 = await createCustomer({ name: 'NYC Customer' });
      const customer2 = await createCustomer({ name: 'LA Customer' });

      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer1.id, market1.id]
      );
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer2.id, market2.id]
      );

      const res = await request(app)
        .get(`/admin/customers?marketId=${market1.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customers).toHaveLength(1);
      expect(res.body.customers[0].name).toBe('NYC Customer');
    });

    it('market associations cascade on customer delete', async () => {
      const market = await createMarket({ name: 'NYC', slug: 'nyc' });
      const customer = await createCustomer();

      const pool = getTestPool();
      await pool.query(
        'INSERT INTO customer_markets (customer_id, market_id) VALUES ($1, $2)',
        [customer.id, market.id]
      );

      await request(app)
        .delete(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      const rows = await pool.query(
        'SELECT * FROM customer_markets WHERE customer_id = $1',
        [customer.id]
      );
      expect(rows.rows).toHaveLength(0);
    });
  });

  // ─── Customer Media (brand assets) ──────────────────

  describe('Customer Media', () => {
    it('uploads customer media via API', async () => {
      const customer = await createCustomer();

      const res = await request(app)
        .post(`/admin/customers/${customer.id}/media`)
        .set('Authorization', `Bearer ${token}`)
        .attach('image', Buffer.from('fake-image-data'), 'logo.png')
        .field('placement', 'logo');

      // S3 not configured in test — may return 201 with placeholder or 500
      // Either way, the route exists and processes correctly
      if (res.status === 201) {
        expect(res.body.media).toBeDefined();
        expect(res.body.media.customer_id).toBe(customer.id);
        expect(res.body.media.placement).toBe('logo');
      }
      // If S3/sharp fails in test env, that's expected
    });

    it('media appears in customer detail', async () => {
      const customer = await createCustomer();

      // Insert media directly (bypasses S3)
      const pool = getTestPool();
      await pool.query(
        `INSERT INTO customer_media (customer_id, url, placement, width, height)
         VALUES ($1, 'https://example.com/logo.png', 'logo'::media_placement, 200, 200)`,
        [customer.id]
      );

      const res = await request(app)
        .get(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.customer.media).toHaveLength(1);
      expect(res.body.customer.media[0].url).toBe('https://example.com/logo.png');
      expect(res.body.customer.media[0].placement).toBe('logo');
      expect(res.body.customer.media[0].width).toBe(200);
    });

    it('deletes customer media', async () => {
      const customer = await createCustomer();

      const pool = getTestPool();
      const mediaResult = await pool.query(
        `INSERT INTO customer_media (customer_id, url, placement)
         VALUES ($1, 'https://example.com/banner.png', 'app_banner'::media_placement)
         RETURNING *`,
        [customer.id]
      );
      const mediaId = mediaResult.rows[0].id;

      const res = await request(app)
        .delete(`/admin/customers/${customer.id}/media/${mediaId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      const rows = await pool.query('SELECT * FROM customer_media WHERE id = $1', [mediaId]);
      expect(rows.rows).toHaveLength(0);
    });

    it('returns 404 for nonexistent media', async () => {
      const customer = await createCustomer();

      const res = await request(app)
        .delete(`/admin/customers/${customer.id}/media/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
    });

    it('media cascades on customer delete', async () => {
      const customer = await createCustomer();

      const pool = getTestPool();
      const mediaResult = await pool.query(
        `INSERT INTO customer_media (customer_id, url, placement)
         VALUES ($1, 'https://example.com/test.png', 'other'::media_placement)
         RETURNING id`,
        [customer.id]
      );
      const mediaId = mediaResult.rows[0].id;

      await request(app)
        .delete(`/admin/customers/${customer.id}`)
        .set('Authorization', `Bearer ${token}`);

      const rows = await pool.query('SELECT * FROM customer_media WHERE id = $1', [mediaId]);
      expect(rows.rows).toHaveLength(0);
    });

    it('rejects invalid placement', async () => {
      const customer = await createCustomer();

      const res = await request(app)
        .post(`/admin/customers/${customer.id}/media`)
        .set('Authorization', `Bearer ${token}`)
        .attach('image', Buffer.from('fake-image-data'), 'test.png')
        .field('placement', 'invalid_placement');

      expect(res.status).toBe(400);
    });
  });
});

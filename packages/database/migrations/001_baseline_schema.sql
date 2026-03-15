-- Industry Night Baseline Schema
-- Version: 001 (v3 — orders, contacts, markets, media)
-- Description: Complete schema — all tables, enums, triggers, and indexes
-- Date: 2026-03-04
--
-- Changes from v2:
--   - Added markets table (geographic foundation, managed reference data)
--   - Added market_id FK on events (ON DELETE RESTRICT)
--   - Added orders + order_items (transactional grouping, replaces customer_products in Phase 4)
--   - Added customer_contacts (multi-contact per customer)
--   - Added customer_media (brand assets) + partner_media (deal-specific creative)
--   - Added customer_markets junction (many-to-many)
--   - Added order_status, contact_role, media_placement enums
--   - Kept customer_products + contact_email/contact_phone/logo_url transitionally (removed in Phase 4)

-- ============================================================
-- EXTENSION
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUM TYPES
-- ============================================================

CREATE TYPE user_role AS ENUM ('user', 'venueStaff', 'platformAdmin');
CREATE TYPE user_source AS ENUM ('app', 'posh', 'admin');
CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'cancelled', 'completed');
CREATE TYPE ticket_status AS ENUM ('purchased', 'checkedIn', 'cancelled', 'refunded');
CREATE TYPE post_type AS ENUM ('general', 'collaboration', 'job', 'announcement');
CREATE TYPE audit_action AS ENUM (
    'create', 'update', 'delete',
    'login', 'logout',
    'verify', 'reject',
    'ban', 'unban',
    'checkin'
);
CREATE TYPE admin_role AS ENUM ('platformAdmin');
CREATE TYPE discount_type AS ENUM ('percentage', 'fixedAmount', 'freeItem', 'buyOneGetOne', 'other');

-- Customer & product model
CREATE TYPE product_type AS ENUM ('sponsorship', 'vendor_space', 'data_product');
CREATE TYPE sponsorship_tier AS ENUM ('bronze', 'silver', 'gold', 'platinum');
CREATE TYPE vendor_category AS ENUM ('food', 'beverage', 'equipment', 'service', 'venue', 'other');
CREATE TYPE redemption_method AS ENUM ('self_reported', 'code_entry', 'qr_scan');

-- Customer products (transitional — will be replaced by orders in Phase 4)
CREATE TYPE customer_product_status AS ENUM ('active', 'expired', 'cancelled', 'pending');

-- v3: Orders, contacts, markets, media
CREATE TYPE order_status AS ENUM ('draft', 'confirmed', 'paid', 'fulfilled', 'cancelled');
CREATE TYPE contact_role AS ENUM ('primary', 'billing', 'decision_maker', 'other');
CREATE TYPE media_placement AS ENUM ('app_banner', 'web_banner', 'social_media', 'logo', 'other');

-- ============================================================
-- TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================
-- TIER 0: No foreign keys
-- ============================================================

-- Users (social app — phone-based auth)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255),
    name VARCHAR(100),
    bio TEXT,
    profile_photo_url TEXT,
    role user_role NOT NULL DEFAULT 'user',
    source user_source NOT NULL DEFAULT 'app',
    specialties TEXT[] DEFAULT '{}',
    social_links JSONB,
    verification_status verification_status NOT NULL DEFAULT 'unverified',
    profile_completed BOOLEAN NOT NULL DEFAULT false,
    banned BOOLEAN NOT NULL DEFAULT false,
    -- Privacy & consent
    analytics_consent BOOLEAN NOT NULL DEFAULT false,
    marketing_consent BOOLEAN NOT NULL DEFAULT false,
    profile_visibility VARCHAR(20) NOT NULL DEFAULT 'connections',
    consent_updated_at TIMESTAMP WITH TIME ZONE,
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_verification_status ON users(verification_status);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_specialties ON users USING GIN(specialties);

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verification codes (SMS login — keyed by phone, not user_id)
CREATE TABLE verification_codes (
    phone VARCHAR(20) PRIMARY KEY,
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Specialties reference table (admin-managed)
CREATE TABLE specialties (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_specialties_category ON specialties(category);
CREATE INDEX idx_specialties_active ON specialties(is_active, sort_order);

-- Admin users (admin app — email/password auth, separate from social users)
CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    role admin_role NOT NULL DEFAULT 'platformAdmin',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_active ON admin_users(is_active);

CREATE TRIGGER update_admin_users_updated_at
    BEFORE UPDATE ON admin_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- NOTE: venues table removed (pre-release cleanup). Events use venue_name/venue_address text fields directly.

-- Customers (businesses with commercial relationships — replaces sponsors + vendors)
-- Note: contact_email, contact_phone moved to customer_contacts; logo_url moved to customer_media
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    website VARCHAR(500),
    logo_url TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    is_active BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customers_active ON customers(is_active);
CREATE INDEX idx_customers_name ON customers(name);

CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Products (catalog of what IN sells: sponsorships, vendor space, data products)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_type product_type NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price_cents INTEGER,
    is_standard BOOLEAN NOT NULL DEFAULT true,
    config JSONB NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_type ON products(product_type);
CREATE INDEX idx_products_active ON products(is_active);
CREATE INDEX idx_products_standard ON products(is_standard);

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Markets (geographic foundation — managed reference table, never deleted, retired via is_active)
CREATE TABLE markets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    timezone VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_markets_active ON markets(is_active, sort_order);
CREATE INDEX idx_markets_slug ON markets(slug);

CREATE TRIGGER update_markets_updated_at
    BEFORE UPDATE ON markets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- TIER 1: References tier 0 only
-- ============================================================

-- Events
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    venue_name VARCHAR(255),
    venue_address TEXT,
    market_id UUID REFERENCES markets(id) ON DELETE RESTRICT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    activation_code VARCHAR(20),
    posh_event_id VARCHAR(255),
    status event_status NOT NULL DEFAULT 'draft',
    capacity INTEGER,
    attendee_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_time ON events(start_time);
CREATE INDEX idx_events_posh_id ON events(posh_event_id);
CREATE INDEX idx_events_market ON events(market_id);

CREATE TRIGGER update_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- TIER 2: References tier 0 + tier 1
-- ============================================================

-- Customer products (transitional — will be replaced by orders in Phase 4)
CREATE TABLE customer_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    status customer_product_status NOT NULL DEFAULT 'active',
    price_paid_cents INTEGER,
    start_date DATE,
    end_date DATE,
    config_overrides JSONB NOT NULL DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(customer_id, product_id, event_id)
);

CREATE INDEX idx_customer_products_customer ON customer_products(customer_id);
CREATE INDEX idx_customer_products_product ON customer_products(product_id);
CREATE INDEX idx_customer_products_event ON customer_products(event_id);
CREATE INDEX idx_customer_products_status ON customer_products(status);

CREATE TRIGGER update_customer_products_updated_at
    BEFORE UPDATE ON customer_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Orders (transactional grouping — a deal between IN and a customer)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    order_number VARCHAR(20) NOT NULL UNIQUE,
    order_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status order_status NOT NULL DEFAULT 'draft',
    total_amount_cents INTEGER,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Customer contacts (multi-contact per customer)
CREATE TABLE customer_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    role contact_role NOT NULL DEFAULT 'other',
    title VARCHAR(255),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customer_contacts_customer ON customer_contacts(customer_id);

CREATE TRIGGER update_customer_contacts_updated_at
    BEFORE UPDATE ON customer_contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Customer markets (many-to-many: customer operates in multiple markets)
CREATE TABLE customer_markets (
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    market_id UUID NOT NULL REFERENCES markets(id) ON DELETE CASCADE,
    PRIMARY KEY (customer_id, market_id)
);

-- Customer media (brand assets — logo, banners reused across all deals)
CREATE TABLE customer_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    placement media_placement NOT NULL DEFAULT 'other',
    width INTEGER,
    height INTEGER,
    alt_text VARCHAR(255),
    sort_order SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customer_media_customer ON customer_media(customer_id);

-- Event images (up to 5 per event, sort_order 0 = hero)
CREATE TABLE event_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    sort_order SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_event_images_event_id ON event_images(event_id);

-- Tickets (walk-in / manual check-in — Posh purchases go to posh_orders)
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    posh_ticket_id VARCHAR(255),
    posh_order_id VARCHAR(255),
    ticket_type VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status ticket_status NOT NULL DEFAULT 'purchased',
    checked_in_at TIMESTAMP WITH TIME ZONE,
    purchased_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tickets_user_id ON tickets(user_id);
CREATE INDEX idx_tickets_event_id ON tickets(event_id);
CREATE INDEX idx_tickets_posh_ticket_id ON tickets(posh_ticket_id);
CREATE UNIQUE INDEX idx_tickets_posh_ticket_unique ON tickets(posh_ticket_id) WHERE posh_ticket_id IS NOT NULL;

-- Connections (QR scan = instant mutual connection)
CREATE TABLE connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_a_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT different_users CHECK (user_a_id != user_b_id)
);

CREATE INDEX idx_connections_user_a ON connections(user_a_id);
CREATE INDEX idx_connections_user_b ON connections(user_b_id);
CREATE INDEX idx_connections_event ON connections(event_id);
CREATE UNIQUE INDEX idx_connections_unique ON connections(
    LEAST(user_a_id, user_b_id),
    GREATEST(user_a_id, user_b_id)
);

-- Posts (community feed)
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    image_urls TEXT[] DEFAULT '{}',
    type post_type NOT NULL DEFAULT 'general',
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_hidden BOOLEAN NOT NULL DEFAULT false,
    like_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_type ON posts(type);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Discounts/Perks (linked to customers — any customer can offer perks)
CREATE TABLE discounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type discount_type NOT NULL DEFAULT 'percentage',
    value DECIMAL(10, 2),
    code VARCHAR(50),
    terms TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_discounts_customer ON discounts(customer_id);
CREATE INDEX idx_discounts_active ON discounts(is_active);

CREATE TRIGGER update_discounts_updated_at
    BEFORE UPDATE ON discounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Posh orders (stores Posh webhook purchases — IS the canonical Posh ticket)
CREATE TABLE posh_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Posh identifiers
    posh_event_id VARCHAR(255) NOT NULL,
    order_number VARCHAR(255) NOT NULL,
    -- Matched to our event (NULL if posh_event_id not yet linked)
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    -- Buyer info (flat fields from Posh payload)
    account_first_name VARCHAR(100),
    account_last_name VARCHAR(100),
    account_email VARCHAR(255),
    account_phone VARCHAR(20),
    -- Order financials
    items JSONB NOT NULL,
    subtotal DECIMAL(10, 2),
    total DECIMAL(10, 2),
    promo_code VARCHAR(50),
    date_purchased TIMESTAMP WITH TIME ZONE,
    -- IN account linkage (populated when buyer joins and we match by phone/email)
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- Invite tracking (NULL = invite not yet sent)
    invite_sent_at TIMESTAMP WITH TIME ZONE,
    -- Check-in (NULL = not checked in)
    checked_in_at TIMESTAMP WITH TIME ZONE,
    -- Full raw payload preserved for debugging
    raw_payload JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT posh_orders_order_number_unique UNIQUE (order_number)
);

CREATE INDEX idx_posh_orders_posh_event_id ON posh_orders(posh_event_id);
CREATE INDEX idx_posh_orders_event_id ON posh_orders(event_id);
CREATE INDEX idx_posh_orders_user_id ON posh_orders(user_id);
CREATE INDEX idx_posh_orders_account_phone ON posh_orders(account_phone);
CREATE INDEX idx_posh_orders_account_email ON posh_orders(account_email);

-- ============================================================
-- TIER 3: References tier 2
-- ============================================================

-- Order items (line items in an order — links product + optional event)
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    unit_price_cents INTEGER,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_event ON order_items(event_id);

CREATE TRIGGER update_order_items_updated_at
    BEFORE UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Partner media (deal-specific creative — per order item)
CREATE TABLE partner_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    placement media_placement NOT NULL DEFAULT 'other',
    width INTEGER,
    height INTEGER,
    alt_text VARCHAR(255),
    sort_order SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_partner_media_order_item ON partner_media(order_item_id);

-- Post comments
CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_post_comments_post ON post_comments(post_id);

-- Post likes
CREATE TABLE post_likes (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- Discount redemptions (tracks when app users claim perks — Tier 2 revenue data)
CREATE TABLE discount_redemptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    discount_id UUID NOT NULL REFERENCES discounts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method redemption_method NOT NULL DEFAULT 'self_reported',
    redeemed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT,
    CONSTRAINT unique_user_discount_redemption UNIQUE (discount_id, user_id)
);

CREATE INDEX idx_discount_redemptions_discount ON discount_redemptions(discount_id);
CREATE INDEX idx_discount_redemptions_user ON discount_redemptions(user_id);

-- ============================================================
-- TIER 4: Audit + analytics
-- ============================================================

-- Audit log (tracks all significant actions)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action audit_action NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    old_values JSONB,
    new_values JSONB,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_metadata ON audit_log USING GIN(metadata);

-- Data export requests (GDPR/CCPA compliance)
CREATE TABLE data_export_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    download_url TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_data_export_user ON data_export_requests(user_id);
CREATE INDEX idx_data_export_status ON data_export_requests(status);

-- Daily connection stats by specialty pairing (anonymized)
CREATE TABLE analytics_connections_daily (
    date DATE NOT NULL,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    city VARCHAR(100),
    specialty_a VARCHAR(50) NOT NULL,
    specialty_b VARCHAR(50) NOT NULL,
    connection_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (date, event_id, specialty_a, specialty_b)
);

CREATE INDEX idx_analytics_conn_date ON analytics_connections_daily(date DESC);
CREATE INDEX idx_analytics_conn_city ON analytics_connections_daily(city);

-- Daily user activity stats (anonymized)
CREATE TABLE analytics_users_daily (
    date DATE NOT NULL,
    city VARCHAR(100),
    specialty VARCHAR(50),
    new_users INTEGER NOT NULL DEFAULT 0,
    active_users INTEGER NOT NULL DEFAULT 0,
    verified_users INTEGER NOT NULL DEFAULT 0,
    checkins INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (date, city, specialty)
);

CREATE INDEX idx_analytics_users_date ON analytics_users_daily(date DESC);

-- Event performance stats
CREATE TABLE analytics_events (
    event_id UUID PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
    total_checkins INTEGER NOT NULL DEFAULT 0,
    unique_attendees INTEGER NOT NULL DEFAULT 0,
    connections_made INTEGER NOT NULL DEFAULT 0,
    top_specialties JSONB,
    avg_connections_per_user DECIMAL(5,2),
    cross_specialty_rate DECIMAL(5,4),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Network influence scores (updated periodically)
CREATE TABLE analytics_influence (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    connection_count INTEGER NOT NULL DEFAULT 0,
    events_attended INTEGER NOT NULL DEFAULT 0,
    network_reach INTEGER NOT NULL DEFAULT 0,
    specialty_rank INTEGER,
    city_rank INTEGER,
    influence_score DECIMAL(10,4),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analytics_influence_score ON analytics_influence(influence_score DESC);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Markets (geographic foundation)
INSERT INTO markets (id, name, slug, description, timezone, sort_order) VALUES
    (uuid_generate_v4(), 'NYC', 'nyc', 'New York City metro area', 'America/New_York', 0),
    (uuid_generate_v4(), 'LA', 'la', 'Los Angeles metro area', 'America/Los_Angeles', 1),
    (uuid_generate_v4(), 'Atlanta', 'atlanta', 'Atlanta metro area', 'America/New_York', 2);

-- Standard product catalog

INSERT INTO products (id, product_type, name, description, base_price_cents, is_standard, config, sort_order) VALUES
    -- Sponsorships: Platform-level
    (uuid_generate_v4(), 'sponsorship', 'Platform Sponsorship — Bronze',
     'Annual app-level sponsorship with basic logo placement',
     250000, true, '{"level": "platform", "tier": "bronze"}', 10),
    (uuid_generate_v4(), 'sponsorship', 'Platform Sponsorship — Silver',
     'Annual app-level sponsorship with enhanced visibility',
     500000, true, '{"level": "platform", "tier": "silver"}', 11),
    (uuid_generate_v4(), 'sponsorship', 'Platform Sponsorship — Gold',
     'Annual app-level sponsorship with premium placement and audience access',
     1000000, true, '{"level": "platform", "tier": "gold"}', 12),
    (uuid_generate_v4(), 'sponsorship', 'Platform Sponsorship — Platinum',
     'Annual app-level sponsorship with full audience access and data partnership',
     2000000, true, '{"level": "platform", "tier": "platinum"}', 13),

    -- Sponsorships: Event-level
    (uuid_generate_v4(), 'sponsorship', 'Event Sponsorship — Bronze',
     'Per-event sponsorship with logo on event page',
     50000, true, '{"level": "event", "tier": "bronze"}', 20),
    (uuid_generate_v4(), 'sponsorship', 'Event Sponsorship — Silver',
     'Per-event sponsorship with logo placement and featured perk',
     100000, true, '{"level": "event", "tier": "silver"}', 21),
    (uuid_generate_v4(), 'sponsorship', 'Event Sponsorship — Gold',
     'Per-event sponsorship with premium placement, perks, and post-event report',
     200000, true, '{"level": "event", "tier": "gold"}', 22),
    (uuid_generate_v4(), 'sponsorship', 'Event Sponsorship — Platinum',
     'Per-event sponsorship with full visibility, perks, data access, and dedicated support',
     500000, true, '{"level": "event", "tier": "platinum"}', 23),

    -- Vendor space
    (uuid_generate_v4(), 'vendor_space', 'Vendor Space — Standard Booth',
     'Standard booth space at an event',
     30000, true, '{"booth_size": "standard"}', 30),
    (uuid_generate_v4(), 'vendor_space', 'Vendor Space — Premium Booth',
     'Premium booth space with prime positioning and enhanced signage',
     60000, true, '{"booth_size": "premium"}', 31),

    -- Data products
    (uuid_generate_v4(), 'data_product', 'Event Performance Report',
     'Post-event report: check-ins, connections, demographics, top specialties',
     50000, true, '{"format": "pdf", "scope": "single_event", "frequency": "one_time"}', 40),
    (uuid_generate_v4(), 'data_product', 'Quarterly Audience Report',
     'Quarterly audience intelligence: growth trends, specialty demographics, engagement patterns',
     500000, true, '{"format": "pdf", "scope": "all_events", "frequency": "quarterly"}', 41),
    (uuid_generate_v4(), 'data_product', 'Dashboard Access',
     'Ongoing access to real-time audience analytics dashboard',
     200000, true, '{"format": "dashboard", "scope": "custom", "frequency": "ongoing"}', 42);

-- ============================================================
-- MIGRATION TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS _migrations (
    filename VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

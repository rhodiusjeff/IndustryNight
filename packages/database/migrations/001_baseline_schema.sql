-- Industry Night Baseline Schema
-- Version: 001 (consolidated from original migrations 001-004)
-- Description: Complete schema — all tables, enums, triggers, and indexes
-- Date: 2026-03-02

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
CREATE TYPE sponsor_tier AS ENUM ('bronze', 'silver', 'gold', 'platinum');
CREATE TYPE vendor_category AS ENUM ('food', 'beverage', 'equipment', 'service', 'venue', 'other');
CREATE TYPE discount_type AS ENUM ('percentage', 'fixedAmount', 'freeItem', 'buyOneGetOne', 'other');

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

-- Venues (legacy — new events use venue_name/venue_address text fields on events)
CREATE TABLE venues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_venues_updated_at
    BEFORE UPDATE ON venues
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
    venue_id UUID REFERENCES venues(id),
    venue_name VARCHAR(255),
    venue_address TEXT,
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

CREATE TRIGGER update_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sponsors
CREATE TABLE sponsors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    logo_url TEXT,
    website VARCHAR(500),
    tier sponsor_tier NOT NULL DEFAULT 'bronze',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sponsors_tier ON sponsors(tier);
CREATE INDEX idx_sponsors_active ON sponsors(is_active);

CREATE TRIGGER update_sponsors_updated_at
    BEFORE UPDATE ON sponsors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- TIER 2: References tier 0 + tier 1
-- ============================================================

-- Event images (up to 5 per event, sort_order 0 = hero)
CREATE TABLE event_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    sort_order SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_event_images_event_id ON event_images(event_id);

-- Event sponsors (many-to-many: events <-> sponsors)
CREATE TABLE event_sponsors (
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    sponsor_id UUID NOT NULL REFERENCES sponsors(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, sponsor_id)
);

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

-- Discounts/Perks
CREATE TABLE discounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sponsor_id UUID NOT NULL REFERENCES sponsors(id) ON DELETE CASCADE,
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

CREATE INDEX idx_discounts_sponsor ON discounts(sponsor_id);
CREATE INDEX idx_discounts_active ON discounts(is_active);

CREATE TRIGGER update_discounts_updated_at
    BEFORE UPDATE ON discounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Vendors
CREATE TABLE vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    logo_url TEXT,
    website VARCHAR(500),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    category vendor_category NOT NULL DEFAULT 'other',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vendors_category ON vendors(category);
CREATE INDEX idx_vendors_active ON vendors(is_active);

CREATE TRIGGER update_vendors_updated_at
    BEFORE UPDATE ON vendors
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

-- Event vendors (many-to-many: events <-> vendors)
CREATE TABLE event_vendors (
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, vendor_id)
);

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

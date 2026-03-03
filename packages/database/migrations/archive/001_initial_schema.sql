-- Industry Night Initial Schema
-- Version: 001
-- Description: Core tables for users, events, connections, and posts

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enum types
CREATE TYPE user_role AS ENUM ('user', 'venueStaff', 'platformAdmin');
CREATE TYPE user_source AS ENUM ('app', 'posh', 'admin');
CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'cancelled', 'completed');
-- connection_status removed: QR scan = instant connection, delete = disconnect
CREATE TYPE ticket_status AS ENUM ('purchased', 'checkedIn', 'cancelled', 'refunded');
CREATE TYPE post_type AS ENUM ('general', 'collaboration', 'job', 'announcement');

-- Users table
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
    analytics_consent BOOLEAN NOT NULL DEFAULT false,        -- Opted in to anonymized analytics
    marketing_consent BOOLEAN NOT NULL DEFAULT false,        -- Opted in to sponsor communications
    profile_visibility VARCHAR(20) NOT NULL DEFAULT 'connections',  -- 'public', 'connections', 'private'
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

-- Verification codes (for SMS login)
CREATE TABLE verification_codes (
    phone VARCHAR(20) PRIMARY KEY,
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Specialties reference table (pre-populated, admin-managed)
CREATE TABLE specialties (
    id VARCHAR(50) PRIMARY KEY,           -- 'hair_stylist', 'makeup_artist', etc.
    name VARCHAR(100) NOT NULL,            -- 'Hair Stylist', 'Makeup Artist'
    category VARCHAR(50) NOT NULL,         -- 'beauty', 'photo_video', 'production', 'talent'
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_specialties_category ON specialties(category);
CREATE INDEX idx_specialties_active ON specialties(is_active, sort_order);

-- Venues (referenced by events)
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

-- Events table
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    venue_id UUID REFERENCES venues(id),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    image_url TEXT,
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

-- Tickets table
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

-- Connections table (networking via QR scan - instant mutual connection)
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

-- Posts table (community feed)
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

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_venues_updated_at
    BEFORE UPDATE ON venues
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Audit log (tracks all significant actions in the system)
CREATE TYPE audit_action AS ENUM (
    'create', 'update', 'delete',
    'login', 'logout',
    'verify', 'reject',
    'ban', 'unban',
    'checkin'
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action audit_action NOT NULL,
    entity_type VARCHAR(50) NOT NULL,          -- 'user', 'event', 'connection', 'post', etc.
    entity_id UUID,                             -- ID of affected entity (nullable for some actions)
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- Who performed the action
    old_values JSONB,                           -- Previous state (for updates/deletes)
    new_values JSONB,                           -- New state (for creates/updates)
    metadata JSONB,                             -- Additional context (IP, user agent, etc.)
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_metadata ON audit_log USING GIN(metadata);

-- ============================================================================
-- ANALYTICS TABLES (privacy-safe aggregations for sponsors/data clients)
-- ============================================================================

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
    top_specialties JSONB,                    -- Array of {specialty, count}
    avg_connections_per_user DECIMAL(5,2),
    cross_specialty_rate DECIMAL(5,4),        -- % of connections across different specialties
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Network influence scores (updated periodically, privacy-safe)
CREATE TABLE analytics_influence (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    connection_count INTEGER NOT NULL DEFAULT 0,
    events_attended INTEGER NOT NULL DEFAULT 0,
    network_reach INTEGER NOT NULL DEFAULT 0,  -- 2nd degree connections
    specialty_rank INTEGER,                     -- Rank within their primary specialty
    city_rank INTEGER,                          -- Rank within their city
    influence_score DECIMAL(10,4),              -- Composite score
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Only compute influence for users who consent
CREATE INDEX idx_analytics_influence_score ON analytics_influence(influence_score DESC);

-- Data export requests (for compliance tracking)
CREATE TABLE data_export_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_type VARCHAR(50) NOT NULL,         -- 'export', 'delete', 'anonymize'
    status VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'processing', 'completed', 'failed'
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    download_url TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_data_export_user ON data_export_requests(user_id);
CREATE INDEX idx_data_export_status ON data_export_requests(status);

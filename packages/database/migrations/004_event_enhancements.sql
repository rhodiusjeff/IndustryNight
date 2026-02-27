-- Event Enhancements
-- Version: 004
-- Description: Multi-image support, sponsor associations, venue text fields,
--              and posh_orders table replacing webhook-driven ticket creation

-- ============================================================
-- EVENTS: add venue text fields
-- ============================================================

ALTER TABLE events
    ADD COLUMN venue_name    VARCHAR(255),
    ADD COLUMN venue_address TEXT;

-- Backfill venue_name / venue_address from the venues table for any events
-- that had a venue_id FK.  New events use these text fields directly.
UPDATE events
SET venue_name    = v.name,
    venue_address = NULLIF(
        TRIM(
            COALESCE(v.address || ', ', '') ||
            COALESCE(v.city    || ', ', '') ||
            COALESCE(v.state   || ' ',  '') ||
            COALESCE(v.zip, '')
        ), ''
    )
FROM venues v
WHERE events.venue_id = v.id
  AND events.venue_name IS NULL;

-- ============================================================
-- EVENT_IMAGES: up to 5 images per event, sort_order 0 = hero
-- ============================================================

CREATE TABLE event_images (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id    UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    url         TEXT NOT NULL,
    sort_order  SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_event_images_event_id ON event_images(event_id);

-- Backfill any existing single-image events into the new table before
-- dropping the column.  uploaded_at is approximated from created_at.
INSERT INTO event_images (event_id, url, sort_order, uploaded_at)
SELECT id, image_url, 0, created_at
FROM   events
WHERE  image_url IS NOT NULL;

-- Now safe to drop — data has been preserved in event_images
ALTER TABLE events DROP COLUMN IF EXISTS image_url;

-- ============================================================
-- EVENT_SPONSORS: many-to-many between events and sponsors
-- ============================================================

CREATE TABLE event_sponsors (
    event_id   UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    sponsor_id UUID NOT NULL REFERENCES sponsors(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, sponsor_id)
);

-- ============================================================
-- POSH_ORDERS: stores Posh webhook purchases
--
-- Replaces the previous pattern of auto-creating users + tickets
-- from Posh webhook payloads. A posh_order IS the ticket.
-- user_id is NULL until the buyer creates an IN account and
-- we reconcile by phone or email. checked_in_at is stamped
-- when they use the activation code at the event door.
-- ============================================================

CREATE TABLE posh_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Posh identifiers (from real webhook payload)
    posh_event_id  VARCHAR(255) NOT NULL,
    order_number   VARCHAR(255) NOT NULL,

    -- Matched to our event (NULL if posh_event_id not yet linked)
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,

    -- Buyer info (flat fields from Posh payload)
    account_first_name VARCHAR(100),
    account_last_name  VARCHAR(100),
    account_email      VARCHAR(255),
    account_phone      VARCHAR(20),

    -- Order financials
    items      JSONB           NOT NULL,  -- [{item_id, name, price}, ...]
    subtotal   DECIMAL(10, 2),
    total      DECIMAL(10, 2),
    promo_code VARCHAR(50),

    date_purchased TIMESTAMP WITH TIME ZONE,

    -- IN account linkage (populated when buyer joins and we match by phone/email)
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Invite tracking (NULL = invite not yet sent)
    invite_sent_at TIMESTAMP WITH TIME ZONE,

    -- Check-in (NULL = not checked in)
    checked_in_at TIMESTAMP WITH TIME ZONE,

    -- Full raw payload preserved for debugging and future field additions
    raw_payload JSONB NOT NULL,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT posh_orders_order_number_unique UNIQUE (order_number)
);

CREATE INDEX idx_posh_orders_posh_event_id ON posh_orders(posh_event_id);
CREATE INDEX idx_posh_orders_event_id      ON posh_orders(event_id);
CREATE INDEX idx_posh_orders_user_id       ON posh_orders(user_id);
CREATE INDEX idx_posh_orders_account_phone ON posh_orders(account_phone);
CREATE INDEX idx_posh_orders_account_email ON posh_orders(account_email);

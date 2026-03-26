-- Standard Product Catalog
-- Platform reference data — safe to apply on any environment (dev or prod).
-- Inserted by db-reset.js after specialties.sql, before dev_seed.sql.
-- Products use ON CONFLICT DO NOTHING so this file is safe to re-run.

INSERT INTO products (id, product_type, name, description, base_price_cents, is_standard, config, sort_order)
VALUES
    -- Sponsorships: Platform-level
    ('10000000-0000-0000-0000-000000000001', 'sponsorship', 'Platform Sponsorship — Bronze',
     'Annual app-level sponsorship with basic logo placement',
     250000, true, '{"level": "platform", "tier": "bronze"}', 10),
    ('10000000-0000-0000-0000-000000000002', 'sponsorship', 'Platform Sponsorship — Silver',
     'Annual app-level sponsorship with enhanced visibility',
     500000, true, '{"level": "platform", "tier": "silver"}', 11),
    ('10000000-0000-0000-0000-000000000003', 'sponsorship', 'Platform Sponsorship — Gold',
     'Annual app-level sponsorship with premium placement and audience access',
     1000000, true, '{"level": "platform", "tier": "gold"}', 12),
    ('10000000-0000-0000-0000-000000000004', 'sponsorship', 'Platform Sponsorship — Platinum',
     'Annual app-level sponsorship with full audience access and data partnership',
     2000000, true, '{"level": "platform", "tier": "platinum"}', 13),

    -- Sponsorships: Event-level
    ('10000000-0000-0000-0000-000000000011', 'sponsorship', 'Event Sponsorship — Bronze',
     'Per-event sponsorship with logo on event page',
     50000, true, '{"level": "event", "tier": "bronze"}', 20),
    ('10000000-0000-0000-0000-000000000012', 'sponsorship', 'Event Sponsorship — Silver',
     'Per-event sponsorship with logo placement and featured perk',
     100000, true, '{"level": "event", "tier": "silver"}', 21),
    ('10000000-0000-0000-0000-000000000013', 'sponsorship', 'Event Sponsorship — Gold',
     'Per-event sponsorship with premium placement, perks, and post-event report',
     200000, true, '{"level": "event", "tier": "gold"}', 22),
    ('10000000-0000-0000-0000-000000000014', 'sponsorship', 'Event Sponsorship — Platinum',
     'Per-event sponsorship with full visibility, perks, data access, and dedicated support',
     500000, true, '{"level": "event", "tier": "platinum"}', 23),

    -- Vendor space
    ('10000000-0000-0000-0000-000000000021', 'vendor_space', 'Vendor Space — Standard Booth',
     'Standard booth space at an event',
     30000, true, '{"booth_size": "standard"}', 30),
    ('10000000-0000-0000-0000-000000000022', 'vendor_space', 'Vendor Space — Premium Booth',
     'Premium booth space with prime positioning and enhanced signage',
     60000, true, '{"booth_size": "premium"}', 31),

    -- Data products
    ('10000000-0000-0000-0000-000000000031', 'data_product', 'Event Performance Report',
     'Post-event report: check-ins, connections, demographics, top specialties',
     50000, true, '{"format": "pdf", "scope": "single_event", "frequency": "one_time"}', 40),
    ('10000000-0000-0000-0000-000000000032', 'data_product', 'Quarterly Audience Report',
     'Quarterly audience intelligence: growth trends, specialty demographics, engagement patterns',
     500000, true, '{"format": "pdf", "scope": "all_events", "frequency": "quarterly"}', 41),
    ('10000000-0000-0000-0000-000000000033', 'data_product', 'Dashboard Access',
     'Ongoing access to real-time audience analytics dashboard',
     200000, true, '{"format": "dashboard", "scope": "custom", "frequency": "ongoing"}', 42)
ON CONFLICT (id) DO NOTHING;

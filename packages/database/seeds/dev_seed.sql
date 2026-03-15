-- Development Seed Data
-- Use for local development only

-- Create test admin user (email: admin@industrynight.net, password: admin123456)
INSERT INTO admin_users (id, email, password_hash, name, role, is_active) VALUES
    ('ad000000-0000-0000-0000-000000000001', 'admin@industrynight.net', '$2a$12$MnKczAZv50NMkt8eTaXMiuKir9R0G05NcGaNwXJdGP2/x.XmdXAOG', 'Dev Admin', 'platformAdmin', true);

-- Create test users
INSERT INTO users (id, phone, name, email, role, specialties, verification_status, profile_completed, source) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '+11234567890', 'Admin User', 'admin@example.com', 'platformAdmin', ARRAY['producer'], 'verified', true, 'admin'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '+11234567891', 'Test User 1', 'user1@example.com', 'user', ARRAY['photographer', 'videographer'], 'verified', true, 'app'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '+11234567892', 'Test User 2', 'user2@example.com', 'user', ARRAY['hair_stylist'], 'pending', true, 'posh'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '+11234567893', 'Test User 3', NULL, 'user', ARRAY['makeup_artist', 'model'], 'unverified', false, 'app');

-- Create test events (January linked to LA market via subquery)
INSERT INTO events (id, name, description, venue_name, venue_address, start_time, end_time, status, activation_code, capacity, posh_event_id, market_id) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Industry Night LA - January', 'Monthly industry night event', 'The Grand Venue', '123 Main St, Los Angeles, CA 90001', NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days' + INTERVAL '4 hours', 'published', 'JAN2024', 200, 'posh-seed-001', (SELECT id FROM markets WHERE slug = 'la')),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Industry Night LA - February', 'Monthly industry night event', 'The Grand Venue', '123 Main St, Los Angeles, CA 90001', NOW() + INTERVAL '37 days', NOW() + INTERVAL '37 days' + INTERVAL '4 hours', 'draft', 'FEB2024', 200, NULL, NULL);

-- Note: event images are uploaded via admin UI, not seeded (URLs are environment-specific)

-- Create test tickets
INSERT INTO tickets (user_id, event_id, ticket_type, price, status, purchased_at) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'General Admission', 25.00, 'purchased', NOW()),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'VIP', 50.00, 'purchased', NOW());

-- Create test connections (QR scan = instant, no status field)
INSERT INTO connections (user_a_id, user_b_id, event_id) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');

-- Create test customers (replaces sponsors + vendors)
INSERT INTO customers (id, name, description, website, contact_email, is_active) VALUES
    ('11111111-2222-3333-4444-555555555555', 'Beauty Supply Co', 'Premium beauty supplies for professionals', 'https://beautysupplyco.example.com', 'info@beautysupplyco.example.com', true),
    ('22222222-3333-4444-5555-666666666666', 'Camera World', 'Professional photography equipment', 'https://cameraworld.example.com', 'sales@cameraworld.example.com', true),
    ('33333333-4444-5555-6666-777777777777', 'Gourmet Catering', 'Premium event catering', 'https://gourmetcatering.example.com', 'events@gourmetcatering.example.com', true),
    ('44444444-5555-6666-7777-888888888888', 'Pro Audio LA', 'Sound equipment rentals', 'https://proaudiola.example.com', 'rentals@proaudiola.example.com', true);

-- Link customers to products (purchases)
-- Beauty Supply Co: Gold Event Sponsorship for January event
INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, status) VALUES
    ('11111111-2222-3333-4444-555555555555',
     (SELECT id FROM products WHERE name = 'Event Sponsorship — Gold' LIMIT 1),
     'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 200000, 'active');

-- Camera World: Silver Event Sponsorship for January event
INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, status) VALUES
    ('22222222-3333-4444-5555-666666666666',
     (SELECT id FROM products WHERE name = 'Event Sponsorship — Silver' LIMIT 1),
     'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 100000, 'active');

-- Gourmet Catering: Standard Vendor Space for January event
INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, status) VALUES
    ('33333333-4444-5555-6666-777777777777',
     (SELECT id FROM products WHERE name = 'Vendor Space — Standard Booth' LIMIT 1),
     'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 30000, 'active');

-- Pro Audio LA: Standard Vendor Space for January event
INSERT INTO customer_products (customer_id, product_id, event_id, price_paid_cents, status) VALUES
    ('44444444-5555-6666-7777-888888888888',
     (SELECT id FROM products WHERE name = 'Vendor Space — Standard Booth' LIMIT 1),
     'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 30000, 'active');

-- Create test discounts (linked to customers, not sponsors)
INSERT INTO discounts (customer_id, title, description, type, value, code, is_active) VALUES
    ('11111111-2222-3333-4444-555555555555', '20% Off All Products', 'Valid for verified industry members', 'percentage', 20, 'INDUSTRY20', true),
    ('22222222-3333-4444-5555-666666666666', '$50 Off Rentals', 'First rental discount', 'fixedAmount', 50, 'FIRST50', true);

-- Create test posts
INSERT INTO posts (id, author_id, content, type, like_count, comment_count) VALUES
    ('ab111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Just wrapped up an amazing photoshoot! #industrynight #creative', 'general', 5, 2),
    ('ab222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Looking for a photographer for a project next week. DM me!', 'collaboration', 3, 1);

-- Add test comments
INSERT INTO post_comments (post_id, author_id, content) VALUES
    ('ab111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Looks amazing!'),
    ('ab111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Great work!');

-- Add test likes
INSERT INTO post_likes (post_id, user_id) VALUES
    ('ab111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    ('ab111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd');

SELECT 'Seed data inserted successfully!' as status;

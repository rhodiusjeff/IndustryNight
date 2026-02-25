-- Development Seed Data
-- Use for local development only

-- Create a test venue
INSERT INTO venues (id, name, address, city, state, zip) VALUES
    ('11111111-1111-1111-1111-111111111111', 'The Grand Venue', '123 Main St', 'Los Angeles', 'CA', '90001');

-- Create test users
INSERT INTO users (id, phone, name, email, role, specialties, verification_status, profile_completed, source) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '+11234567890', 'Admin User', 'admin@example.com', 'platformAdmin', ARRAY['producer'], 'verified', true, 'admin'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '+11234567891', 'Test User 1', 'user1@example.com', 'user', ARRAY['photographer', 'videographer'], 'verified', true, 'app'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '+11234567892', 'Test User 2', 'user2@example.com', 'user', ARRAY['hair_stylist'], 'pending', true, 'posh'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '+11234567893', 'Test User 3', NULL, 'user', ARRAY['makeup_artist', 'model'], 'unverified', false, 'app');

-- Create test events
INSERT INTO events (id, name, description, venue_id, start_time, end_time, status, activation_code, capacity) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Industry Night LA - January', 'Monthly industry night event', '11111111-1111-1111-1111-111111111111', NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days' + INTERVAL '4 hours', 'published', 'JAN2024', 200),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Industry Night LA - February', 'Monthly industry night event', '11111111-1111-1111-1111-111111111111', NOW() + INTERVAL '37 days', NOW() + INTERVAL '37 days' + INTERVAL '4 hours', 'draft', 'FEB2024', 200);

-- Create test tickets
INSERT INTO tickets (user_id, event_id, ticket_type, price, status, purchased_at) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'General Admission', 25.00, 'purchased', NOW()),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'VIP', 50.00, 'purchased', NOW());

-- Create test connections (QR scan = instant, no status field)
INSERT INTO connections (user_a_id, user_b_id, event_id) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');

-- Create test sponsors
INSERT INTO sponsors (id, name, description, website, tier, is_active) VALUES
    ('11111111-2222-3333-4444-555555555555', 'Beauty Supply Co', 'Premium beauty supplies for professionals', 'https://beautysupplyco.example.com', 'gold', true),
    ('22222222-3333-4444-5555-666666666666', 'Camera World', 'Professional photography equipment', 'https://cameraworld.example.com', 'silver', true);

-- Create test discounts
INSERT INTO discounts (sponsor_id, title, description, type, value, code, is_active) VALUES
    ('11111111-2222-3333-4444-555555555555', '20% Off All Products', 'Valid for verified industry members', 'percentage', 20, 'INDUSTRY20', true),
    ('22222222-3333-4444-5555-666666666666', '$50 Off Rentals', 'First rental discount', 'fixedAmount', 50, 'FIRST50', true);

-- Create test vendors
INSERT INTO vendors (name, description, category, is_active) VALUES
    ('Gourmet Catering', 'Premium event catering', 'food', true),
    ('Pro Audio LA', 'Sound equipment rentals', 'equipment', true);

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

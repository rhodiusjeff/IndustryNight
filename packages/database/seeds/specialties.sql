-- Reference data for specialties
-- Run after initial schema migration

INSERT INTO specialties (id, name, category, sort_order) VALUES
-- Beauty
('hair_stylist', 'Hair Stylist', 'beauty', 10),
('makeup_artist', 'Makeup Artist', 'beauty', 20),
('nail_tech', 'Nail Technician', 'beauty', 30),
('esthetician', 'Esthetician', 'beauty', 40),
('barber', 'Barber', 'beauty', 50),

-- Photo & Video
('photographer', 'Photographer', 'photo_video', 100),
('videographer', 'Videographer', 'photo_video', 110),
('editor', 'Photo/Video Editor', 'photo_video', 120),
('colorist', 'Colorist', 'photo_video', 130),

-- Production
('producer', 'Producer', 'production', 200),
('director', 'Director', 'production', 210),
('creative_director', 'Creative Director', 'production', 220),
('art_director', 'Art Director', 'production', 230),
('production_assistant', 'Production Assistant', 'production', 240),

-- Talent
('model', 'Model', 'talent', 300),
('actor', 'Actor', 'talent', 310),
('dancer', 'Dancer', 'talent', 320),
('influencer', 'Influencer/Content Creator', 'talent', 330),

-- Music & Audio
('dj', 'DJ', 'music_audio', 400),
('music_producer', 'Music Producer', 'music_audio', 410),
('sound_engineer', 'Sound Engineer', 'music_audio', 420),
('musician', 'Musician', 'music_audio', 430),

-- Design
('fashion_designer', 'Fashion Designer', 'design', 500),
('graphic_designer', 'Graphic Designer', 'design', 510),
('stylist', 'Wardrobe Stylist', 'design', 520),
('set_designer', 'Set Designer', 'design', 530),

-- Other Creative
('writer', 'Writer/Copywriter', 'other', 600),
('artist', 'Visual Artist', 'other', 610),
('animator', 'Animator', 'other', 620),
('other', 'Other', 'other', 999)

ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    sort_order = EXCLUDED.sort_order;

-- Example queries:
-- Find users by specialty:
--   SELECT * FROM users WHERE 'photographer' = ANY(specialties);
--
-- Find users with multiple specialties:
--   SELECT * FROM users WHERE specialties @> ARRAY['photographer', 'videographer'];
--
-- Get all active specialties grouped by category:
--   SELECT category, array_agg(name ORDER BY sort_order)
--   FROM specialties WHERE is_active = true GROUP BY category;

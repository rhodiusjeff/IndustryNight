-- Add full Posh event URL storage to support direct social-app navigation.
-- Keep posh_event_id as canonical linkage key for webhook reconciliation.

ALTER TABLE events
ADD COLUMN IF NOT EXISTS posh_event_url TEXT;

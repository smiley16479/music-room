-- Migration: Remove duplicate fields from Playlist table
-- All metadata (name, description, visibility, etc.) are now in Event table
-- Playlist only contains playback-specific data (trackCount, totalDuration)

-- Step 1: Add coverImageUrl to events table if not exists
ALTER TABLE events
ADD COLUMN IF NOT EXISTS cover_image_url VARCHAR(255);

-- Step 2: Migrate existing playlist cover images to events
UPDATE events e
SET cover_image_url = p.cover_image_url
FROM playlists p
WHERE p.event_id = e.id
  AND p.cover_image_url IS NOT NULL
  AND e.cover_image_url IS NULL;

-- Step 3: Remove duplicate columns from playlists table
ALTER TABLE playlists
DROP COLUMN IF EXISTS name,
DROP COLUMN IF EXISTS description,
DROP COLUMN IF EXISTS is_public,
DROP COLUMN IF EXISTS cover_image_url;

-- Note: The following columns are kept in playlists:
-- - id (primary key)
-- - event_id (foreign key to events - MANDATORY)
-- - total_duration (computed from tracks)
-- - track_count (computed from tracks)
-- - created_at
-- - updated_at

-- Verification: Ensure all playlists have an associated event
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM playlists WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'Migration failed: Found playlists without event_id. All playlists must have an associated event.';
  END IF;
END
$$;

COMMENT ON TABLE playlists IS 'Playlist entity - Contains only playback stats. All metadata (name, description, permissions) are in the associated Event.';
COMMENT ON COLUMN playlists.event_id IS 'MANDATORY 1:1 relation with Event. Event is the aggregate root.';

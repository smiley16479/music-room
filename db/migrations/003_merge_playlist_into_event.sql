-- Migration: Merge Playlist into Event (Single Table Inheritance)
-- All playlists become Events of type LISTENING_SESSION
-- This eliminates the Playlist table entirely

-- Step 1: Add playlist-specific columns to events table
ALTER TABLE events
ADD COLUMN IF NOT EXISTS track_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_duration INT DEFAULT 0;

-- Step 2: Migrate existing playlists to events
-- For each playlist, either update its existing event or create a new one
DO $$
DECLARE
  playlist_record RECORD;
  new_event_id UUID;
BEGIN
  FOR playlist_record IN 
    SELECT id, event_id, track_count, total_duration, created_at, updated_at
    FROM playlists
  LOOP
    IF playlist_record.event_id IS NOT NULL THEN
      -- Update existing event with playlist stats
      UPDATE events
      SET 
        track_count = playlist_record.track_count,
        total_duration = playlist_record.total_duration
      WHERE id = playlist_record.event_id;
      
    ELSE
      -- This should not happen since all playlists must have an event
      RAISE EXCEPTION 'Playlist % has no event_id', playlist_record.id;
    END IF;
  END LOOP;
END $$;

-- Step 3: Rename column in playlist_tracks table (playlist_id → event_id)
-- First, update the values to point to events instead of playlists
UPDATE playlist_tracks pt
SET playlist_id = (
  SELECT event_id 
  FROM playlists p 
  WHERE p.id = pt.playlist_id
);

-- Rename the column
ALTER TABLE playlist_tracks
RENAME COLUMN playlist_id TO event_id;

-- Step 4: Update foreign key constraint
ALTER TABLE playlist_tracks
DROP CONSTRAINT IF EXISTS playlist_tracks_playlist_id_fkey,
ADD CONSTRAINT playlist_tracks_event_id_fkey 
  FOREIGN KEY (event_id) 
  REFERENCES events(id) 
  ON DELETE CASCADE;

-- Step 5: Update index
DROP INDEX IF EXISTS IDX_playlist_tracks_playlist_position;
CREATE INDEX IDX_playlist_tracks_event_position 
  ON playlist_tracks(event_id, position);

-- Step 6: Drop the playlists table (no longer needed)
DROP TABLE IF EXISTS playlists CASCADE;

-- Step 7: Add comments for documentation
COMMENT ON COLUMN events.track_count IS 'Number of tracks in the event playlist (NULL for events without playlists)';
COMMENT ON COLUMN events.total_duration IS 'Total duration of all tracks in seconds (NULL for events without playlists)';
COMMENT ON TABLE playlist_tracks IS 'Tracks in an event. For LISTENING_SESSION type, these are playlist tracks. For other types, these can be event queue tracks.';
COMMENT ON COLUMN playlist_tracks.event_id IS 'Reference to the event containing these tracks (formerly playlist_id)';

-- Verification queries
DO $$
BEGIN
  -- Check that all playlist_tracks have valid event_id
  IF EXISTS (SELECT 1 FROM playlist_tracks WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'Migration failed: Found playlist_tracks with NULL event_id';
  END IF;
  
  -- Check that all events with track_count have corresponding tracks
  IF EXISTS (
    SELECT e.id 
    FROM events e 
    WHERE e.track_count > 0 
      AND e.track_count != (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.event_id = e.id)
  ) THEN
    RAISE WARNING 'Some events have inconsistent track_count values';
  END IF;
  
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Playlists are now merged into Events';
  RAISE NOTICE 'Use type=LISTENING_SESSION for playlist-only events';
END $$;

# Architecture Simplification: Event-Centric Model

## Overview

This refactoring eliminates data duplication between `Playlist` and `Event` entities by making Event the **Aggregate Root** (DDD pattern).

## Changes Made

### 1. Playlist Entity Simplification

**Before:**
```typescript
class Playlist {
  id: string;
  name: string;                    // ❌ REMOVED - now in Event
  description: string;             // ❌ REMOVED - now in Event  
  isPublic: boolean;              // ❌ REMOVED - use Event.visibility
  coverImageUrl: string;          // ❌ REMOVED - now in Event
  creatorId: string;              // ❌ REMOVED - use Event.creatorId
  collaborators: User[];          // ❌ REMOVED - use Event.participants
  trackCount: number;             // ✅ KEPT - playback stat
  totalDuration: number;          // ✅ KEPT - playback stat
  eventId: string;                // ✅ KEPT - relation to Event
}
```

**After:**
```typescript
class Playlist {
  id: string;
  trackCount: number;             // ✅ Playback stat
  totalDuration: number;          // ✅ Playback stat
  eventId: string;                // ✅ MANDATORY 1:1 with Event
  event: Event;                   // ✅ Navigation property
  createdAt: Date;
  updatedAt: Date;
}
```

### 2. Event Entity Extensions

**Added:**
```typescript
class Event {
  coverImageUrl: string;  // NEW: Moved from Playlist
  // ... existing fields (name, description, visibility, participants)
}
```

### 3. Service Layer Updates

#### PlaylistService

**Metadata Access:**
```typescript
// OLD
const playlistName = playlist.name;

// NEW  
const playlistName = playlist.event.name;
```

**Creating Playlists:**
```typescript
// Creates Event first, then Playlist
async create(dto: CreatePlaylistDto, userId: string) {
  const event = await this.eventRepository.save({
    name: dto.name,
    description: dto.description,
    coverImageUrl: dto.coverImageUrl,
    creatorId: userId,
    type: EventType.LISTENING_SESSION,
    visibility: EventVisibility.PRIVATE,
  });
  
  const playlist = await this.playlistRepository.save({
    eventId: event.id,
    trackCount: 0,
    totalDuration: 0,
  });
  
  return playlist;
}
```

**Updating Playlists:**
```typescript
// Updates Event metadata, not Playlist
async update(id: string, dto: UpdatePlaylistDto, userId: string) {
  const playlist = await this.findById(id);
  
  // Update Event metadata (name, description, coverImageUrl)
  Object.assign(playlist.event, dto);
  await this.eventRepository.save(playlist.event);
  
  return playlist;
}
```

#### Query Modifications

**Before:**
```sql
SELECT * FROM playlists p
WHERE p.name LIKE '%query%'
  AND p.creatorId = 'userId'
  AND p.isPublic = true
```

**After:**
```sql
SELECT * FROM playlists p
JOIN events e ON p.event_id = e.id
WHERE e.name LIKE '%query%'
  AND e.creatorId = 'userId'
  AND e.visibility = 'public'
```

## Benefits

### 1. **DRY Principle** ✅
- Eliminated duplicate fields (name, description, visibility, permissions)
- Single source of truth for all metadata

### 2. **Consistency** ✅
- Permissions managed uniformly via Event.participants
- No risk of Playlist.isPublic conflicting with Event.visibility

### 3. **Simplified Code** ✅
- Removed PlaylistGateway (consolidated into EventGateway)
- Unified permission checking logic
- Less code to maintain

### 4. **Clear Domain Model** ✅
```
Event (Aggregate Root)
├── Metadata (name, description, coverImageUrl)
├── Permissions (visibility, licenseType)
├── Participants (with roles)
└── Playlist (1:1)
    ├── Tracks (ordered list)
    └── Stats (trackCount, totalDuration)
```

## Use Cases

### 1. Personal Playlist
```typescript
Event {
  name: "My Chill Vibes",
  visibility: PRIVATE,
  type: LISTENING_SESSION,
  participants: [owner],
  playlist: { trackCount: 42, ... }
}
```

### 2. Collaborative Event Playlist
```typescript
Event {
  name: "Friday Party",
  visibility: PUBLIC,
  type: PARTY,
  location: {...},
  participants: [creator, user1, user2, ...],
  playlist: { trackCount: 100, ... }
}
```

### 3. Live Session Playlist
```typescript
Event {
  name: "DJ Set Stream",
  visibility: PUBLIC,
  type: LIVE_SESSION,
  votingEnabled: true,
  participants: [dj, listener1, listener2, ...],
  playlist: { trackCount: 50, ... }
}
```

## Migration Guide

### Database Migration
```bash
# Run the migration script
psql -U postgres -d music_room -f db/migrations/002_remove_playlist_duplicates.sql
```

### Frontend Updates Required

**API Response Changes:**
```typescript
// OLD
interface Playlist {
  id: string;
  name: string;
  description: string;
  isPublic: boolean;
  coverImageUrl: string;
}

// NEW
interface Playlist {
  id: string;
  event: {
    name: string;
    description: string;
    visibility: 'public' | 'private';
    coverImageUrl: string;
  }
}
```

**Access Pattern:**
```typescript
// OLD
const playlistName = playlist.name;

// NEW
const playlistName = playlist.event.name;
```

## Testing Checklist

- [ ] Create new playlist → Event created with correct metadata
- [ ] Update playlist name → Event name updated
- [ ] Search playlists → Searches Event.name
- [ ] Filter by visibility → Uses Event.visibility
- [ ] Permission checks → Uses Event.participants
- [ ] WebSocket notifications → Include Event metadata
- [ ] Playlist export → Includes Event metadata
- [ ] Playlist duplication → Copies Event metadata

## Rollback Plan

If needed, restore duplicate fields:
```sql
ALTER TABLE playlists
ADD COLUMN name VARCHAR(200),
ADD COLUMN description TEXT,
ADD COLUMN is_public BOOLEAN DEFAULT false,
ADD COLUMN cover_image_url VARCHAR(255);

UPDATE playlists p
SET 
  name = e.name,
  description = e.description,
  is_public = (e.visibility = 'public'),
  cover_image_url = e.cover_image_url
FROM events e
WHERE p.event_id = e.id;
```

## Related Files Modified

- `back/src/playlist/entities/playlist.entity.ts` - Removed duplicate fields
- `back/src/event/entities/event.entity.ts` - Added coverImageUrl
- `back/src/playlist/playlist.service.ts` - Updated to use Event metadata
- `back/src/event/event.service.ts` - Updated playlist creation
- `back/src/event/event.gateway.ts` - Updated WebSocket payloads
- `back/src/invitation/invitation.service.ts` - Fixed permission checks
- `db/migrations/002_remove_playlist_duplicates.sql` - Database migration

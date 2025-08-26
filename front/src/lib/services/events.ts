import { config } from '$lib/config';
import { authService } from './auth';
import { playlistsService } from './playlists';

export interface Event {
  id: string;
  name: string;
  title: string; // Alias for name for compatibility
  description?: string;
  visibility: 'public' | 'private';
  isPublic: boolean; // Computed from visibility
  licenseType: 'open' | 'invited' | 'location_based';
  status: 'upcoming' | 'live' | 'ended';
  allowsVoting: boolean; // Whether voting is enabled
  coverImageUrl?: string; // Event cover image
  playlistName?: string; // Name of the playlist associated with the event
  playlistId?: string; // ID of the associated playlist
  // Host information
  hostId: string; // Alias for creatorId
  hostName: string; // Host display name

  // Location data
  latitude?: number;
  longitude?: number;
  locationRadius?: number;
  locationName?: string;
  location?: string; // Formatted location string

  // Time constraints
  votingStartTime?: string;
  votingEndTime?: string;
  eventDate?: string;
  eventEndDate?: string;
  startDate?: string; // Alias for eventDate

  // Current playing
  currentTrackId?: string;
  currentTrackStartedAt?: string;
  currentTrack?: Track;

  maxVotesPerUser: number;

  // Relations
  creatorId: string;
  creator: User;
  participants: User[];
  admins?: User[]; // Event administrators
  playlist: Track[];
  votes: Vote[];

  // Stats
  stats?: {
    participantCount: number;
    voteCount: number;
    trackCount: number;
    isUserParticipating: boolean;
  };

  createdAt: string;
  updatedAt: string;
}

export interface Track {
  id: string;
  deezerId?: string;
  title: string;
  artist: string;
  album?: string;
  duration?: number;
  thumbnailUrl?: string;
  previewUrl?: string;
  streamUrl?: string; // Direct stream URL
  isrc?: string;
  voteCount?: number; // Current vote count
  votes?: number; // Alias for voteCount
  addedBy?: string; // User who added the track
  createdAt: string;
  updatedAt: string;
}

export interface User {
  id: string;
  displayName: string;
  username?: string; // Username for compatibility
  email?: string;
  avatarUrl?: string;
  userId?: string; // Alias for id
  joinedAt?: string; // When user joined the event
  createdAt: string;
  updatedAt: string;
}

export interface Vote {
  id: string;
  eventId: string;
  userId: string;
  trackId: string;
  type: 'upvote' | 'downvote';
  weight: number;
  createdAt: string;

  // Relations
  user?: User;
  track?: Track;
}

export interface VoteResult {
  track: Track;
  voteCount: number;
  userVote?: Vote;
  position: number;
}

export interface CreateEventData {
  name: string;
  description?: string;
  visibility?: 'public' | 'private';
  licenseType?: 'open' | 'invited' | 'location_based';
  playlistName?: string;

  // Location data for location-based events
  latitude?: number;
  longitude?: number;
  locationRadius?: number;
  locationName?: string;

  // Time constraints for location-based events
  votingStartTime?: string;
  votingEndTime?: string;
  eventDate?: string;
  eventEndDate?: string;

  maxVotesPerUser?: number;
}

export interface CreateVoteData {
  trackId: string;
  type?: 'upvote' | 'downvote';
  weight?: number;
}

export async function getEvents(fetchFn?: typeof fetch): Promise<Event[]> {
  const fetchToUse = fetchFn || fetch;
  const response = await fetchToUse(`${config.apiUrl}/api/events`, {
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch events');
  }

  const result = await response.json();
  const events = result.data || [];
  
  // Process each event to handle playlist data properly
  const processedEvents = await Promise.all(events.map(async (event: any) => {
    const processedEvent = { ...event };
    
    // Handle playlist data properly
    if (event.playlist) {
      if (typeof event.playlist === 'object' && 'id' in event.playlist) {
        // If playlist is an object with an id, extract the ID and convert tracks to array
        processedEvent.playlistId = event.playlist.id;
        // Extract actual track data from playlistTracks
        if (Array.isArray(event.playlist.playlistTracks)) {
          // Extract track IDs and fetch track data
          const trackIds = event.playlist.playlistTracks.map((pt: any) => pt.trackId).filter(Boolean);
          
          if (trackIds.length > 0) {
            try {
              // Fetch track data using the track IDs
              const trackResponse = await fetchToUse(`${config.apiUrl}/api/music/tracks/batch`, {
                method: 'POST',
                headers: {
                  'Authorization': `Bearer ${authService.getAuthToken()}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ trackIds })
              });
              
              if (trackResponse.ok) {
                const trackResult = await trackResponse.json();
                const tracks = trackResult.data || [];
                
                // Map playlist tracks to actual track data
                processedEvent.playlist = event.playlist.playlistTracks.map((playlistTrack: any) => {
                  const track = tracks.find((t: any) => t.id === playlistTrack.trackId);
                  if (track) {
                    // Map albumCoverUrl to thumbnailUrl for interface compatibility
                    return {
                      ...track,
                      thumbnailUrl: track.albumCoverUrl || track.albumCoverMediumUrl || '',
                      addedBy: playlistTrack.addedById || ''
                    };
                  } else {
                    return {
                      id: playlistTrack.trackId,
                      title: 'Unknown Track',
                      artist: 'Unknown Artist',
                      album: '',
                      duration: 0,
                      thumbnailUrl: '',
                      previewUrl: '',
                      addedBy: playlistTrack.addedById || ''
                    };
                  }
                });
              } else {
                processedEvent.playlist = [];
              }
            } catch (error) {
              processedEvent.playlist = [];
            }
          } else {
            processedEvent.playlist = [];
          }
        } else {
          processedEvent.playlist = [];
        }
      } else if (!Array.isArray(event.playlist)) {
        // If playlist is not an array and doesn't have an id, make it an empty array
        processedEvent.playlist = [];
      }
    } else {
      // If no playlist data, ensure it's an empty array
      processedEvent.playlist = [];
    }
    
    return processedEvent;
  }));

  return processedEvents;
}

export async function getEvent(id: string, fetchFn?: typeof fetch): Promise<Event> {
  const fetchToUse = fetchFn || fetch;
  const response = await fetchToUse(`${config.apiUrl}/api/events/${id}`, {
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch event');
  }

  const result = await response.json();
  const eventData = result.data || result;
  
  // Handle playlist data properly
  if (eventData && eventData.playlist) {
    if (typeof eventData.playlist === 'object' && 'id' in eventData.playlist) {
      // If playlist is an object with an id, extract the ID and convert tracks to array
      eventData.playlistId = eventData.playlist.id;
      // Extract actual track data from playlistTracks
      if (Array.isArray(eventData.playlist.playlistTracks)) {
        // Extract track IDs and fetch track data
        const trackIds = eventData.playlist.playlistTracks.map((pt: any) => pt.trackId).filter(Boolean);
        
        if (trackIds.length > 0) {
          try {
            // Fetch track data using the track IDs
            const trackResponse = await fetchToUse(`${config.apiUrl}/api/music/tracks/batch`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${authService.getAuthToken()}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({ trackIds })
            });
            
            if (trackResponse.ok) {
              const trackResult = await trackResponse.json();
              const tracks = trackResult.data || [];
              
              // Map playlist tracks to actual track data
              eventData.playlist = eventData.playlist.playlistTracks.map((playlistTrack: any) => {
                const track = tracks.find((t: any) => t.id === playlistTrack.trackId);
                if (track) {
                  // Map albumCoverUrl to thumbnailUrl for interface compatibility
                  return {
                    ...track,
                    thumbnailUrl: track.albumCoverUrl || track.albumCoverMediumUrl || '',
                    addedBy: playlistTrack.addedById || ''
                  };
                } else {
                  return {
                    id: playlistTrack.trackId,
                    title: 'Unknown Track',
                    artist: 'Unknown Artist',
                    album: '',
                    duration: 0,
                    thumbnailUrl: '',
                    previewUrl: '',
                    addedBy: playlistTrack.addedById || ''
                  };
                }
              });
            } else {
              eventData.playlist = [];
            }
          } catch (error) {
            eventData.playlist = [];
          }
        } else {
          eventData.playlist = [];
        }
      } else {
        eventData.playlist = [];
      }
    } else if (!Array.isArray(eventData.playlist)) {
      // If playlist is not an array and doesn't have an id, make it an empty array
      eventData.playlist = [];
    }
  } else {
    // If no playlist data, ensure it's an empty array
    eventData.playlist = [];
  }
  
  return eventData;
}

export async function createEvent(eventData: CreateEventData): Promise<Event> {
  // Ensure playlistName has a default value if not provided
  const processedEventData = {
    ...eventData,
    playlistName: eventData.playlistName || eventData.name || 'Default Playlist'
  };

  const response = await fetch(`${config.apiUrl}/api/events`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(processedEventData)
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to create event');
  }

  const result = await response.json();
  return result.data || result;
}

export async function updateEvent(id: string, eventData: Partial<CreateEventData>): Promise<Event> {
  // Process eventData to handle playlistName if it's being updated
  const processedEventData = { ...eventData };
  if ('playlistName' in eventData && (eventData.playlistName === '' || eventData.playlistName === undefined)) {
    processedEventData.playlistName = eventData.name || 'Default Playlist';
  }

  const response = await fetch(`${config.apiUrl}/api/events/${id}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(processedEventData)
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to update event');
  }

  const result = await response.json();
  return result.data || result;
}

export async function deleteEvent(id: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${id}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to delete event');
  }
}

export async function joinEvent(eventId: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/participants`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to join event');
  }
}

export async function leaveEvent(eventId: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/participants`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to leave event');
  }
}

export async function voteForTrack(eventId: string, voteData: CreateVoteData): Promise<VoteResult[]> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/vote`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(voteData)
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to vote for track');
  }

  const result = await response.json();
  return result.data || result;
}

// Convenience function for simple upvoting
export async function voteForTrackSimple(eventId: string, trackId: string): Promise<VoteResult[]> {
  return voteForTrack(eventId, { trackId, type: 'upvote', weight: 1 });
}

export async function removeVote(eventId: string, trackId: string): Promise<VoteResult[]> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/vote/${trackId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to remove vote');
  }

  const result = await response.json();
  return result.data || result;
}

export async function getVotingResults(eventId: string): Promise<VoteResult[]> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/results`, {
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to get voting results');
  }

  const result = await response.json();
  return result.data || result;
}

export async function addTrackToEvent(eventId: string, trackId: string): Promise<void>;
export async function addTrackToEvent(eventId: string, trackData: Partial<Track>): Promise<void>;
export async function addTrackToEvent(eventId: string, trackIdOrData: string | Partial<Track>): Promise<void> {
  try {
    // First, get the event to find its playlist ID
    const event = await getEvent(eventId);
    
    // Extract playlist ID from the event object
    let playlistId = event.playlistId;
    
    // If playlistId is not directly available, try to get it from the playlist object
    if (!playlistId && event.playlist && typeof event.playlist === 'object' && 'id' in event.playlist) {
      playlistId = (event.playlist as any).id;
    }
    
    // If still no playlist ID, try to find it by searching for playlists that match the event name
    if (!playlistId) {
      try {
        const playlists = await playlistsService.getPlaylists(false); // Get all playlists
        const eventPlaylist = playlists.find(p => 
          p.name.includes(`[Event] ${event.name}`) || 
          p.name.includes(event.name)
        );
        if (eventPlaylist) {
          playlistId = eventPlaylist.id;
        }
      } catch (error) {
        // Silently continue if playlist search fails
      }
    }
    
    if (!playlistId) {
      throw new Error(`Event playlist not found for "${event.name}". Please refresh the page and try again.`);
    }

    // Prepare track data for the playlist service
    let trackData: {
      deezerId: string;
      title: string;
      artist: string;
      album: string;
      albumCoverUrl?: string;
      previewUrl?: string;
      duration?: number;
      position?: number;
    };

    if (typeof trackIdOrData === 'string') {
      // If only trackId is provided, we can't add it directly since we need more track information
      throw new Error('Adding tracks by ID only is not supported. Please provide full track data.');
    } else {
      // Track data should be properly formatted from the search modal
      const trackInput = trackIdOrData as any;
      
      trackData = {
        deezerId: trackInput.deezerId || '',
        title: trackInput.title || '',
        artist: trackInput.artist || '',
        album: trackInput.album || '',
        albumCoverUrl: trackInput.albumCoverUrl || '',
        previewUrl: trackInput.previewUrl || '',
        duration: trackInput.duration || 0,
      };

      // Validate required fields
      if (!trackData.deezerId || !trackData.title || !trackData.artist) {
        throw new Error('Track data is incomplete. Title, artist, and deezerId are required.');
      }
    }

    // Use the playlist service to add the track
    await playlistsService.addTrackToPlaylist(playlistId, trackData);
  } catch (error) {
    // Ensure we don't create an infinite loop by re-throwing a clean error
    if (error instanceof Error) {
      throw new Error(error.message);
    } else {
      throw new Error('Failed to add track to event. Please try again.');
    }
  }
}

export async function removeTrackFromEvent(eventId: string, trackId: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/tracks/${trackId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to remove track from event');
  }
}

export async function inviteToEvent(eventId: string, emails: string[]): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/invite`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ emails })
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to send invitations');
  }
}

// Event control functions
export async function startEvent(eventId: string): Promise<Event> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/start`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to start event');
  }

  const result = await response.json();
  return result.data || result;
}

export async function endEvent(eventId: string): Promise<Event> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/end`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to end event');
  }

  const result = await response.json();
  return result.data || result;
}

export async function playNextTrack(eventId: string): Promise<Track | null> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/next-track`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to play next track');
  }

  const result = await response.json();
  return result.data?.track || null;
}

export async function promoteUserToAdmin(eventId: string, userId: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/admins/${userId}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to promote user to admin');
  }
}

export async function removeUserFromAdmin(eventId: string, userId: string): Promise<void> {
  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/admins/${userId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to remove admin');
  }
}

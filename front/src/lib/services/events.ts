import { config } from '$lib/config';
import { authService } from './auth';

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
  return result.data || [];
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
  return result.data || result;
}

export async function createEvent(eventData: CreateEventData): Promise<Event> {
  const response = await fetch(`${config.apiUrl}/api/events`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(eventData)
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to create event');
  }

  const result = await response.json();
  return result.data || result;
}

export async function updateEvent(id: string, eventData: Partial<CreateEventData>): Promise<Event> {
  const response = await fetch(`${config.apiUrl}/api/events/${id}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(eventData)
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
  const body = typeof trackIdOrData === 'string'
    ? { trackId: trackIdOrData }
    : trackIdOrData;

  const response = await fetch(`${config.apiUrl}/api/events/${eventId}/tracks`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authService.getAuthToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.message || 'Failed to add track to event');
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

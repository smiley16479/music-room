import { config } from '$lib/config';
import { authService } from './auth';

export interface Event {
  id: string;
  title: string;
  description?: string;
  hostId: string;
  hostName: string;
  isPublic: boolean;
  allowsVoting: boolean;
  licenseType: 'free' | 'invited_only' | 'location_time';
  startDate?: string;
  endDate?: string;
  location?: string;
  currentTrack?: Track;
  playlist: Track[];
  participants: Participant[];
  votes: Vote[];
  createdAt: string;
  updatedAt: string;
}

export interface Track {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration?: number;
  thumbnailUrl?: string;
  streamUrl?: string;
  votes: number;
  addedBy: string;
  addedAt: string;
}

export interface Participant {
  userId: string;
  displayName: string;
  profilePicture?: string;
  role: 'host' | 'participant';
  joinedAt: string;
}

export interface Vote {
  id: string;
  userId: string;
  trackId: string;
  votedAt: string;
}

export interface CreateEventData {
  title: string;
  description?: string;
  isPublic: boolean;
  allowsVoting: boolean;
  licenseType: 'free' | 'invited_only' | 'location_time';
  startDate?: string;
  endDate?: string;
  location?: string;
}

export const eventsService = {
  async getEvents(isPublic?: boolean, customFetch?: typeof fetch): Promise<Event[]> {
    const token = authService.getAuthToken();
    const queryParams = isPublic !== undefined ? `?isPublic=${isPublic}` : '';
    
    const fetchFn = customFetch || fetch;
    const response = await fetchFn(`${config.apiUrl}/api/events${queryParams}`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch events');
    }

    const result = await response.json();
    return result.data;
  },

  async getEvent(eventId: string): Promise<Event> {
    const token = authService.getAuthToken();
    
    const response = await fetch(`${config.apiUrl}/api/events/${eventId}`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch event');
    }

    const result = await response.json();
    return result.data;
  },

  async createEvent(eventData: CreateEventData): Promise<Event> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/events`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(eventData)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to create event');
    }

    const result = await response.json();
    return result.data;
  },

  async joinEvent(eventId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/events/${eventId}/join`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to join event');
    }
  },

  async leaveEvent(eventId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/events/${eventId}/leave`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to leave event');
    }
  },

  async voteForTrack(eventId: string, trackId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/events/${eventId}/vote`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ trackId })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to vote for track');
    }
  },

  async addTrackToEvent(eventId: string, track: Omit<Track, 'id' | 'votes' | 'addedBy' | 'addedAt'>): Promise<Track> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/events/${eventId}/tracks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(track)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to add track');
    }

    const result = await response.json();
    return result.data;
  }
};

import { config } from '$lib/config';
import { authService } from './auth';

export interface Playlist {
  id: string;
  name: string; // Changed from 'title' to match backend
  description?: string;
  creatorId: string; // Changed from 'ownerId' to match backend
  creator?: { id: string; displayName: string }; // Backend relation
  visibility: 'public' | 'private'; // Changed from 'isPublic' boolean to enum
  isCollaborative: boolean;
  licenseType: 'open' | 'invited'; // Changed from 'free'|'invited_only' to match backend
  trackCount: number; // Track count from backend
  totalDuration: number; // Total duration from backend
  tracks?: PlaylistTrack[]; // Optional - only included in detailed view
  collaborators: Collaborator[];
  coverImageUrl?: string; // Changed from 'thumbnailUrl' to match backend
  createdAt: string;
  updatedAt: string;
}

export interface PlaylistTrack {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration?: number;
  thumbnailUrl?: string;
  streamUrl?: string;
  addedBy: string;
  addedByName: string;
  addedAt: string;
  position: number;
}

export interface Collaborator {
  userId: string;
  displayName: string;
  profilePicture?: string;
  role: 'owner' | 'editor' | 'viewer';
  addedAt: string;
}

export interface CreatePlaylistData {
  name: string; // Changed from 'title' to match backend
  description?: string;
  visibility: 'public' | 'private'; // Changed from 'isPublic' boolean to enum
  isCollaborative: boolean;
  licenseType: 'open' | 'invited'; // Changed from 'free'|'invited_only' to match backend
}

export const playlistsService = {
  async getPlaylists(isPublic?: boolean, userId?: string, customFetch?: typeof fetch): Promise<Playlist[]> {
    const token = authService.getAuthToken();
    const params = new URLSearchParams();
    
    if (isPublic !== undefined) params.append('isPublic', isPublic.toString());
    if (userId) params.append('userId', userId);
    
    const queryString = params.toString() ? `?${params.toString()}` : '';
    
    const fetchFn = customFetch || fetch;
    const response = await fetchFn(`${config.apiUrl}/api/playlists${queryString}`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch playlists');
    }

    const result = await response.json();
    return result.data;
  },

  async getPlaylist(playlistId: string, customFetch?: typeof fetch): Promise<Playlist> {
    const token = authService.getAuthToken();
    
    const fetchFn = customFetch || fetch;
    const response = await fetchFn(`${config.apiUrl}/api/playlists/${playlistId}`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch playlist');
    }

    const result = await response.json();
    return result.data;
  },

  async getPlaylistTracks(playlistId: string): Promise<PlaylistTrack[]> {
    const token = authService.getAuthToken();
    
    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/tracks`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch playlist tracks');
    }

    const result = await response.json();
    return result.data;
  },

  async createPlaylist(playlistData: CreatePlaylistData): Promise<Playlist> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(playlistData)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to create playlist');
    }

    const result = await response.json();
    return result.data;
  },

  async updatePlaylist(playlistId: string, updates: Partial<CreatePlaylistData>): Promise<Playlist> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(updates)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to update playlist');
    }

    const result = await response.json();
    return result.data;
  },

  async deletePlaylist(playlistId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to delete playlist');
    }
  },

  async addTrackToPlaylist(playlistId: string, track: Omit<PlaylistTrack, 'id' | 'addedBy' | 'addedByName' | 'addedAt' | 'position'>): Promise<PlaylistTrack> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/tracks`, {
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
  },

  async removeTrackFromPlaylist(playlistId: string, trackId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/tracks/${trackId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to remove track');
    }
  },

  async reorderTracks(playlistId: string, trackPositions: { trackId: string; position: number }[]): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/reorder`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ trackPositions })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to reorder tracks');
    }
  },

  async addCollaborator(playlistId: string, userId: string, role: 'editor' | 'viewer' = 'viewer'): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/collaborators`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ userId, role })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to add collaborator');
    }
  },

  async removeCollaborator(playlistId: string, userId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/collaborators/${userId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to remove collaborator');
    }
  }
};

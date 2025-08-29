import { config } from '$lib/config';
import { authService } from './auth';
import { socketService } from './socket';

export interface Playlist {
  id: string;
  name: string;
  description?: string;
  creatorId: string;
  creator?: { id: string; displayName: string };
  visibility: 'public' | 'private';
  licenseType: 'open' | 'invited';
  trackCount: number;
  totalDuration: number;
  tracks?: PlaylistTrack[];
  collaborators: Collaborator[];
  coverImageUrl?: string;
  eventId?: string; // If set, this playlist belongs to an event
  createdAt: string;
  updatedAt: string;
}

export interface PlaylistTrack {
  id: string;
  position: number;
  addedAt: string;
  createdAt: string;
  playlistId: string;
  trackId: string;
  addedById: string;
  track: {
    id: string;
    deezerId: string;
    title: string;
    artist: string;
    album: string;
    duration: number;
    previewUrl: string;
    albumCoverUrl: string;
    albumCoverSmallUrl: string;
    albumCoverMediumUrl: string;
    albumCoverBigUrl: string;
    deezerUrl: string;
    genres?: string;
    releaseDate?: string;
    available: boolean;
    createdAt: string;
    updatedAt: string;
  };
  addedBy: {
    id: string;
    displayName: string;
    avatarUrl?: string;
    email?: string;
  };
}

export interface Collaborator {
  id: string;
  displayName: string;
  avatarUrl?: string;
  email?: string;
}

export interface CreatePlaylistData {
  name: string;
  description?: string;
  visibility: 'public' | 'private';
  licenseType: 'open' | 'invited';
}

export const playlistsService = {
  async getPlaylists(isPublic?: boolean, userId?: string, includeEventPlaylists?: boolean, customFetch?: typeof fetch): Promise<Playlist[]> {
    const token = authService.getAuthToken();
    const params = new URLSearchParams();
    
    if (isPublic !== undefined) params.append('isPublic', isPublic.toString());
    if (userId) params.append('userId', userId);
    if (includeEventPlaylists !== undefined) params.append('includeEventPlaylists', includeEventPlaylists.toString());
    
    const queryString = params.toString() ? `?${params.toString()}` : '';
    
    const fetchFn = customFetch || fetch;
    const response = await fetchFn(`${config.apiUrl}/api/playlists${queryString}`, {
      headers: token ? { 'Authorization': `Bearer ${token}` } : {}
    });

    if (!response.ok) {
      throw new Error('Failed to fetch playlists');
    }

    const result = await response.json();
    return result.data || result; // Handle both paginated and non-paginated responses
  },

  async getMyPlaylists(customFetch?: typeof fetch): Promise<Playlist[]> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');
    
    const fetchFn = customFetch || fetch;
    const response = await fetchFn(`${config.apiUrl}/api/playlists/my-playlists`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch my playlists');
    }

    const result = await response.json();
    return result.data || result; // Handle both paginated and non-paginated responses
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
      method: 'PATCH',
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

  async addTrackToPlaylist(playlistId: string, data: {
    deezerId: string;
    title: string;
    artist: string;
    album: string;
    albumCoverUrl?: string;
    previewUrl?: string;
    duration?: number;
    position?: number;
  }): Promise<PlaylistTrack> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/tracks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(data)
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to add track');
    }

    const result = await response.json();
    
    // Emit socket event for real-time updates
    try {
      if (socketService.isConnected()) {
        socketService.emitTrackAdded(playlistId, result.data);
      }
    } catch (error) {
      console.warn('Failed to emit track added event:', error);
    }
    
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

    // Emit socket event for real-time updates
    try {
      if (socketService.isConnected()) {
        socketService.emitTrackRemoved(playlistId, trackId);
      }
    } catch (error) {
      console.warn('Failed to emit track removed event:', error);
    }
  },

  async reorderTracks(playlistId: string, trackIds: string[]): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/tracks/reorder`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ trackIds })
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to reorder tracks');
    }

    // Emit socket event for real-time updates
    try {
      if (socketService.isConnected()) {
        socketService.emitTracksReordered(playlistId, trackIds);
      }
    } catch (error) {
      console.warn('Failed to emit tracks reordered event:', error);
    }
  },

  async addCollaborator(playlistId: string, userId: string): Promise<void> {
    const token = authService.getAuthToken();
    if (!token) throw new Error('Authentication required');

    const response = await fetch(`${config.apiUrl}/api/playlists/${playlistId}/collaborators/${userId}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!response.ok) {
      const result = await response.json();
      throw new Error(result.message || 'Failed to add collaborator');
    }

    // Emit socket event for real-time updates
    try {
      if (socketService.isConnected()) {
        socketService.emitCollaboratorAdded(playlistId, userId);
      }
    } catch (error) {
      console.warn('Failed to emit collaborator added event:', error);
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

    // Emit socket event for real-time updates
    try {
      if (socketService.isConnected()) {
        socketService.emitCollaboratorRemoved(playlistId, userId);
      }
    } catch (error) {
      console.warn('Failed to emit collaborator removed event:', error);
    }
  }
};

import { config } from '$lib/config';
import { authService } from './auth';

// Raw Deezer API format (for internal use)
export interface RawDeezerTrack {
  id: number;
  title: string;
  title_short: string;
  title_version: string;
  link: string;
  duration: number;
  rank: number;
  explicit_lyrics: boolean;
  explicit_content_lyrics: number;
  explicit_content_cover: number;
  preview: string;
  md5_image: string;
  artist: DeezerArtist;
  album: DeezerAlbum;
  type: string;
}

// Our backend Track entity format (what we actually receive)
export interface DeezerTrack {
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
}

export interface DeezerArtist {
  id: number;
  name: string;
  link: string;
  picture: string;
  picture_small: string;
  picture_medium: string;
  picture_big: string;
  picture_xl: string;
  tracklist: string;
  type: string;
}

export interface DeezerAlbum {
  id: number;
  title: string;
  cover: string;
  cover_small: string;
  cover_medium: string;
  cover_big: string;
  cover_xl: string;
  md5_image: string;
  tracklist: string;
  type: string;
}

export interface DeezerSearchResponse {
  data: DeezerTrack[];
  total: number;
  hasMore?: boolean;
  source?: string;
  next?: string;
}

export interface MusicSearchParams {
  query: string;
  artist?: string;
  album?: string;
  limit?: number;
  includeLocal?: boolean;
}

export interface AdvancedSearchParams {
  artist?: string;
  album?: string;
  track?: string;
  genre?: string;
  durationMin?: number;
  durationMax?: number;
  year?: number;
  limit?: number;
}

class DeezerService {
  /**
   * Search for tracks using our backend's music API
   */
  async searchTracks(params: MusicSearchParams): Promise<DeezerSearchResponse> {
    const token = authService.getAuthToken();
    
    const searchParams = new URLSearchParams({
      query: params.query,
      limit: Math.min(Math.max(params.limit || 25, 1), 100).toString(), // Ensure limit is between 1-100
    });

    if (params.artist) searchParams.append('artist', params.artist);
    if (params.album) searchParams.append('album', params.album);
    if (params.includeLocal !== undefined) searchParams.append('includeLocal', params.includeLocal.toString());

    try {
      const response = await fetch(`${config.apiUrl}/api/music/search?${searchParams.toString()}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(errorData?.message || `Music search error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return {
        data: result.data?.tracks || [],
        total: result.data?.total || 0,
        hasMore: result.data?.hasMore || false,
        source: result.data?.source || 'deezer'
      };
    } catch (error) {
      console.error('Error searching tracks:', error);
      throw new Error('Failed to search tracks');
    }
  }

  /**
   * Advanced search for tracks using our backend's music API
   */
  async searchAdvanced(params: AdvancedSearchParams): Promise<DeezerSearchResponse> {
    const token = authService.getAuthToken();
    
    const searchParams = new URLSearchParams();
    
    if (params.artist) searchParams.append('artist', params.artist);
    if (params.album) searchParams.append('album', params.album);
    if (params.track) searchParams.append('track', params.track);
    if (params.genre) searchParams.append('genre', params.genre);
    if (params.durationMin) searchParams.append('durationMin', params.durationMin.toString());
    if (params.durationMax) searchParams.append('durationMax', params.durationMax.toString());
    if (params.year) searchParams.append('year', params.year.toString());
    if (params.limit) searchParams.append('limit', Math.min(Math.max(params.limit, 1), 100).toString());

    try {
      const response = await fetch(`${config.apiUrl}/api/music/search/advanced?${searchParams.toString()}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(errorData?.message || `Advanced music search error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return {
        data: result.data?.tracks || [],
        total: result.data?.total || 0,
        hasMore: result.data?.hasMore || false,
        source: result.data?.source || 'deezer'
      };
    } catch (error) {
      console.error('Error in advanced search:', error);
      throw new Error('Failed to perform advanced search');
    }
  }

  /**
   * Get top tracks using our backend's music API
   */
  async getTopTracks(limit: number = 25): Promise<DeezerSearchResponse> {
    const token = authService.getAuthToken();
    const validLimit = Math.min(Math.max(limit, 1), 100); // Ensure limit is between 1-100

    try {
      const response = await fetch(`${config.apiUrl}/api/music/top?limit=${validLimit}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(errorData?.message || `Get top tracks error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return {
        data: result.data?.tracks || [],
        total: result.data?.total || 0,
        hasMore: result.data?.hasMore || false,
        source: result.data?.source || 'deezer'
      };
    } catch (error) {
      console.error('Error getting top tracks:', error);
      throw new Error('Failed to get top tracks');
    }
  }

  /**
   * Get music genres using our backend's music API
   */
  async getGenres(): Promise<any[]> {
    const token = authService.getAuthToken();

    try {
      const response = await fetch(`${config.apiUrl}/api/music/genres`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        throw new Error(`Get genres error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return result.data;
    } catch (error) {
      console.error('Error getting genres:', error);
      throw new Error('Failed to get genres');
    }
  }

  /**
   * Get track details by ID using our backend's music API
   */
  async getTrack(trackId: number): Promise<DeezerTrack> {
    const token = authService.getAuthToken();

    try {
      const response = await fetch(`${config.apiUrl}/api/music/track/${trackId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        throw new Error(`Get track error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return result.data;
    } catch (error) {
      console.error('Error fetching track:', error);
      throw new Error('Failed to fetch track');
    }
  }

  /**
   * Get artist details by ID using our backend's music API
   */
  async getArtist(artistId: number): Promise<DeezerArtist> {
    const token = authService.getAuthToken();

    try {
      const response = await fetch(`${config.apiUrl}/api/music/artist/${artistId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        throw new Error(`Get artist error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return result.data;
    } catch (error) {
      console.error('Error fetching artist:', error);
      throw new Error('Failed to fetch artist');
    }
  }

  /**
   * Get album details by ID using our backend's music API
   */
  async getAlbum(albumId: number): Promise<DeezerAlbum> {
    const token = authService.getAuthToken();

    try {
      const response = await fetch(`${config.apiUrl}/api/music/album/${albumId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` })
        },
      });

      if (!response.ok) {
        throw new Error(`Get album error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return result.data;
    } catch (error) {
      console.error('Error fetching album:', error);
      throw new Error('Failed to fetch album');
    }
  }
}

export const deezerService = new DeezerService();

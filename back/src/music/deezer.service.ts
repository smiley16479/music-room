import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { Cache } from 'cache-manager';
import { Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { firstValueFrom } from 'rxjs';
import { AxiosError } from 'axios';

import {
  DeezerTrack,
  DeezerSearchResponse,
  DeezerAlbum,
  DeezerArtist,
} from './interfaces/deezer.interface';

@Injectable()
export class DeezerService {
  private readonly logger = new Logger(DeezerService.name);
  private readonly baseUrl = 'https://api.deezer.com';
  
  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  // Search Methods
  async searchTracks(
    query: string,
    limit = 25,
    index = 0,
    strict = false
  ): Promise<DeezerSearchResponse> {
    const cacheKey = `search:tracks:${query}:${limit}:${index}:${strict}`;
    
    try {
      // Check cache first
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        this.logger.debug(`Cache hit for search: ${query}`);
        return cached;
      }

      // Build search query
      const searchQuery = strict ? `"${query}"` : query;
      const url = `${this.baseUrl}/search/track`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: {
            q: searchQuery,
            limit,
            index,
            output: 'json',
          },
        })
      );

      const result = response.data;
      
      // Cache result
      await this.cacheManager.set(cacheKey, result, 300); // 5 minutes
      
      this.logger.debug(`Found ${result.data.length} tracks for query: ${query}`);
      return result;

    } catch (error) {
      this.logger.error(`Search error for "${query}":`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  async searchAdvanced(params: {
    artist?: string;
    album?: string;
    track?: string;
    label?: string;
    dur_min?: number;
    dur_max?: number;
    bpm_min?: number;
    bpm_max?: number;
    limit?: number;
    index?: number;
  }): Promise<DeezerSearchResponse> {
    const cacheKey = `search:advanced:${JSON.stringify(params)}`;
    
    try {
      // Check cache first
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        return cached;
      }

      // Build advanced search query - use simple combined search instead of field-specific syntax
      const queryParts: string[] = [];
      
      if (params.artist) queryParts.push(params.artist);
      if (params.album) queryParts.push(params.album);
      if (params.track) queryParts.push(params.track);
      if (params.label) queryParts.push(params.label);

      const query = queryParts.join(' ');
      
      // If no query parts, return empty result
      if (!query.trim()) {
        return { data: [], total: 0 };
      }

      const url = `${this.baseUrl}/search/track`;

      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: {
            q: query,
            limit: params.limit || 25,
            index: params.index || 0,
            output: 'json',
          },
        })
      );      const result = response.data;
      
      // Cache result
      await this.cacheManager.set(cacheKey, result, 600); // 10 minutes for advanced searches
      
      return result;

    } catch (error) {
      this.logger.error(`Advanced search error:`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  async searchByGenre(genreId: number, limit = 25, index = 0): Promise<DeezerSearchResponse> {
    const cacheKey = `search:genre:${genreId}:${limit}:${index}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/genre/${genreId}/tracks`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: { limit, index },
        })
      );

      const result = response.data;
      await this.cacheManager.set(cacheKey, result, 1800); // 30 minutes
      
      return result;

    } catch (error) {
      this.logger.error(`Genre search error for ${genreId}:`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  // Track Details
  async getTrack(trackId: string): Promise<DeezerTrack | null> {
    const cacheKey = `track:${trackId}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerTrack>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/track/${trackId}`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerTrack>(url)
      );

      const track = response.data;
      
      // Cache for longer since track details don't change often
      await this.cacheManager.set(cacheKey, track, 3600); // 1 hour
      
      return track;

    } catch (error) {
      this.logger.error(`Track fetch error for ${trackId}:`, this.handleError(error));
      return null;
    }
  }

  // Album Details
  async getAlbum(albumId: string): Promise<DeezerAlbum | null> {
    const cacheKey = `album:${albumId}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerAlbum>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/album/${albumId}`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerAlbum>(url)
      );

      const album = response.data;
      await this.cacheManager.set(cacheKey, album, 3600); // 1 hour
      
      return album;

    } catch (error) {
      this.logger.error(`Album fetch error for ${albumId}:`, this.handleError(error));
      return null;
    }
  }

  // Artist Details
  async getArtist(artistId: string): Promise<DeezerArtist | null> {
    const cacheKey = `artist:${artistId}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerArtist>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/artist/${artistId}`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerArtist>(url)
      );

      const artist = response.data;
      await this.cacheManager.set(cacheKey, artist, 3600); // 1 hour
      
      return artist;

    } catch (error) {
      this.logger.error(`Artist fetch error for ${artistId}:`, this.handleError(error));
      return null;
    }
  }

  async getArtistTopTracks(artistId: string, limit = 25): Promise<DeezerSearchResponse> {
    const cacheKey = `artist:${artistId}:top:${limit}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/artist/${artistId}/top`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: { limit },
        })
      );

      const result = response.data;
      await this.cacheManager.set(cacheKey, result, 1800); // 30 minutes
      
      return result;

    } catch (error) {
      this.logger.error(`Artist top tracks error for ${artistId}:`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  // Recommendations and Discovery
  async getTopTracks(limit = 25): Promise<DeezerSearchResponse> {
    const cacheKey = `chart:tracks:${limit}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/chart/0/tracks`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: { limit },
        })
      );

      const result = response.data;
      await this.cacheManager.set(cacheKey, result, 3600); // 1 hour
      
      return result;

    } catch (error) {
      this.logger.error(`Top tracks fetch error:`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  async getRadioTracks(radioId: number, limit = 25): Promise<DeezerSearchResponse> {
    const cacheKey = `radio:${radioId}:tracks:${limit}`;
    
    try {
      const cached = await this.cacheManager.get<DeezerSearchResponse>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/radio/${radioId}/tracks`;
      
      const response = await firstValueFrom(
        this.httpService.get<DeezerSearchResponse>(url, {
          params: { limit },
        })
      );

      const result = response.data;
      await this.cacheManager.set(cacheKey, result, 1800); // 30 minutes
      
      return result;

    } catch (error) {
      this.logger.error(`Radio tracks error for ${radioId}:`, this.handleError(error));
      return { data: [], total: 0 };
    }
  }

  // Genre Information
  async getGenres(): Promise<any[]> {
    const cacheKey = 'genres:all';
    
    try {
      const cached = await this.cacheManager.get<any[]>(cacheKey);
      if (cached) {
        return cached;
      }

      const url = `${this.baseUrl}/genre`;
      
      const response = await firstValueFrom(
        this.httpService.get<{ data: any[] }>(url)
      );

      const genres = response.data.data;
      await this.cacheManager.set(cacheKey, genres, 86400); // 24 hours
      
      return genres;

    } catch (error) {
      this.logger.error(`Genres fetch error:`, this.handleError(error));
      return [];
    }
  }

  // Utility Methods
  async isTrackAvailable(trackId: string): Promise<boolean> {
    const track = await this.getTrack(trackId);
    return track !== null;
  }

  async getMultipleTracks(trackIds: string[]): Promise<(DeezerTrack | null)[]> {
    const promises = trackIds.map(id => this.getTrack(id));
    return Promise.all(promises);
  }

  extractTrackIdFromUrl(url: string): string | null {
    const patterns = [
      /deezer\.com\/track\/(\d+)/,
      /deezer\.com\/.*\/track\/(\d+)/,
      /deezer\.page\.link\/.*track\/(\d+)/,
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        return match[1];
      }
    }

    return null;
  }

  buildTrackUrl(trackId: string): string {
    return `https://www.deezer.com/track/${trackId}`;
  }

  private handleError(error: any): string {
    if (error instanceof AxiosError) {
      if (error.response) {
        return `HTTP ${error.response.status}: ${JSON.stringify(error.response.data)}`;
      } else if (error.request) {
        return 'Network error - no response received';
      } else {
        return `Request error: ${error.message}`;
      }
    }
    
    return error.message || 'Unknown error';
  }

  // Cache Management
  async clearCache(pattern?: string): Promise<void> {
    if (pattern) {
      // Note: cache-manager doesn't support pattern clearing by default
      // You might need to implement this based on your cache store
      this.logger.warn(`Pattern cache clearing not implemented for: ${pattern}`);
    } else {
      // await this.cacheManager.reset();
      this.logger.warn('All Deezer cache NOT cleared see me ');
    }
  }

  async getCacheStats(): Promise<any> {
    // Implementation depends on cache store
    return {
      message: 'Cache stats not implemented for current cache store',
      store: 'memory',
    };
  }
}
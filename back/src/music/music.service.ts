import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';

import { DeezerService } from './deezer.service';
import { YouTubeService } from './youtube.service';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';

import { SearchTrackDto } from './dto/search-track.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { DeezerTrack } from './interfaces/deezer.interface';

export interface SearchResult {
  tracks: Track[];
  total: number;
  source: 'deezer' | 'local' | 'mixed';
  hasMore: boolean;
}

export interface TrackRecommendations {
  recommended: Track[];
  reason: string;
  basedOn?: {
    type: 'user_preferences' | 'track_similarity' | 'genre' | 'artist';
    data: any;
  };
}

@Injectable()
export class MusicService {
  private readonly logger = new Logger(MusicService.name);

  constructor(
    @InjectRepository(Track)
    private readonly trackRepository: Repository<Track>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly deezerService: DeezerService,
    private readonly youtubeService: YouTubeService,
  ) {}

  // Search Methods
  async searchTracks(searchDto: SearchTrackDto): Promise<SearchResult> {
    const { query, artist, album, limit = 25, includeLocal = true } = searchDto;
    
    try {
      // Search on Deezer
      const deezerResults = await this.searchOnDeezer(query, artist, album, limit);
      
      // Convert Deezer tracks for search results (keeps original preview URLs)
      const deezerTracks = deezerResults.data.map(deezerTrack => 
        this.convertDeezerTrackForSearch(deezerTrack)
      );

      // Search local tracks if requested
      let localTracks: Track[] = [];
      if (includeLocal) {
        localTracks = await this.searchLocalTracks(query, artist, album, limit);
      }

      // Combine and deduplicate results
      const combinedTracks = this.combineAndDeduplicateTracks(localTracks, deezerTracks);
      
      // Limit final results
      const finalTracks = combinedTracks.slice(0, limit);

      return {
        tracks: finalTracks,
        total: Math.max(deezerResults.total, combinedTracks.length),
        source: localTracks.length > 0 && deezerTracks.length > 0 ? 'mixed' : 
                localTracks.length > 0 ? 'local' : 'deezer',
        hasMore: deezerResults.total > limit || combinedTracks.length > limit,
      };

    } catch (error) {
      this.logger.error(`Search error for "${query}":`, error);
      
      // Fallback to local search only
      if (includeLocal) {
        const localTracks = await this.searchLocalTracks(query, artist, album, limit);
        return {
          tracks: localTracks,
          total: localTracks.length,
          source: 'local',
          hasMore: false,
        };
      }

      return {
        tracks: [],
        total: 0,
        source: 'deezer',
        hasMore: false,
      };
    }
  }

  async searchAdvanced(params: {
    artist?: string;
    album?: string;
    track?: string;
    genre?: string;
    durationMin?: number;
    durationMax?: number;
    year?: number;
    limit?: number;
  }): Promise<SearchResult> {
    const limit = params.limit || 25;

    try {
      // Advanced search on Deezer
      const deezerResults = await this.deezerService.searchAdvanced({
        artist: params.artist,
        album: params.album,
        track: params.track,
        dur_min: params.durationMin,
        dur_max: params.durationMax,
        limit,
      });

      const tracks = deezerResults.data.map(deezerTrack => 
        this.convertDeezerTrackForSearch(deezerTrack)
      );

      return {
        tracks,
        total: deezerResults.total,
        source: 'deezer',
        hasMore: deezerResults.total > limit,
      };

    } catch (error) {
      this.logger.error(`Advanced search error:`, error);
      return { tracks: [], total: 0, source: 'deezer', hasMore: false };
    }
  }

  async getTrackById(trackId: string): Promise<Track | null> {
    // First, try to find in local database
    let track = await this.trackRepository.findOne({ where: { id: trackId } });
    
    if (track) {
      return track;
    }

    // If not found locally, try to find by Deezer ID
    track = await this.trackRepository.findOne({ where: { deezerId: trackId } });
    
    if (track) {
      return track;
    }

    // If still not found, fetch from Deezer and save
    const deezerTrack = await this.deezerService.getTrack(trackId);
    if (deezerTrack) {
      return this.convertDeezerTrack(deezerTrack);
    }

    return null;
  }

  async getTrackByDeezerId(deezerId: string): Promise<Track | null> {
    // Check local database first
    let track = await this.trackRepository.findOne({ where: { deezerId } });
    
    if (track) {
      return track;
    }

    // Fetch from Deezer and save
    const deezerTrack = await this.deezerService.getTrack(deezerId);
    if (deezerTrack) {
      return this.convertDeezerTrack(deezerTrack);
    }

    return null;
  }

  async getMultipleTracks(trackIds: string[]): Promise<Track[]> {
    const tracks: Track[] = [];
    const missingIds: string[] = [];

    // First, get tracks from local database
    const localTracks = await this.trackRepository.find({
      where: { id: In(trackIds) },
    });

    const localTrackIds = localTracks.map(t => t.id);
    tracks.push(...localTracks);

    // Find missing tracks
    for (const id of trackIds) {
      if (!localTrackIds.includes(id)) {
        missingIds.push(id);
      }
    }

    // Fetch missing tracks from Deezer
    if (missingIds.length > 0) {
      const deezerTracks = await this.deezerService.getMultipleTracks(missingIds);
      
      for (const deezerTrack of deezerTracks) {
        if (deezerTrack) {
          const convertedTrack = await this.convertDeezerTrack(deezerTrack);
          tracks.push(convertedTrack);
        }
      }
    }

    // Return tracks in the same order as requested
    return trackIds.map(id => tracks.find(t => t.id === id || t.deezerId === id)).filter(Boolean) as Track[];
  }

  // Recommendations
  async getRecommendationsForUser(userId: string, limit = 25): Promise<TrackRecommendations> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    
    if (!user || !user.musicPreferences) {
      // Return popular tracks if no preferences
      return this.getPopularTracks(limit);
    }

    const preferences = user.musicPreferences;
    const recommendations: Track[] = [];

    try {
      // Get recommendations based on favorite genres
      if (preferences.favoriteGenres && preferences.favoriteGenres.length > 0) {
        for (const genre of preferences.favoriteGenres.slice(0, 3)) { // Top 3 genres
          const genreResults = await this.searchTracks({ 
            query: genre, 
            limit: Math.ceil(limit / 3),
            includeLocal: false 
          });
          recommendations.push(...genreResults.tracks);
        }
      }

      // Get recommendations based on favorite artists
      if (preferences.favoriteArtists && preferences.favoriteArtists.length > 0) {
        for (const artist of preferences.favoriteArtists.slice(0, 2)) { // Top 2 artists
          const artistResults = await this.searchTracks({ 
            query: '', 
            artist, 
            limit: Math.ceil(limit / 4),
            includeLocal: false 
          });
          recommendations.push(...artistResults.tracks);
        }
      }

      // Remove duplicates and limit results
      const uniqueRecommendations = this.removeDuplicateTracks(recommendations).slice(0, limit);

      return {
        recommended: uniqueRecommendations,
        reason: 'Based on your music preferences',
        basedOn: {
          type: 'user_preferences',
          data: {
            genres: preferences.favoriteGenres,
            artists: preferences.favoriteArtists,
          },
        },
      };

    } catch (error) {
      this.logger.error(`Recommendations error for user ${userId}:`, error);
      return this.getPopularTracks(limit);
    }
  }

  async getSimilarTracks(trackId: string, limit = 25): Promise<TrackRecommendations> {
    const baseTrack = await this.getTrackById(trackId);
    
    if (!baseTrack) {
      throw new NotFoundException('Base track not found');
    }

    try {
      // Get similar tracks by artist
      const artistTracks = await this.searchTracks({
        query: '',
        artist: baseTrack.artist,
        limit: Math.ceil(limit * 0.6), // 60% from same artist
        includeLocal: false,
      });

      // Get similar tracks by genre (if available)
      let genreTracks: Track[] = [];
      if (baseTrack.genres && baseTrack.genres.length > 0) {
        const genreResults = await this.searchTracks({
          query: baseTrack.genres[0],
          limit: Math.ceil(limit * 0.4), // 40% from same genre
          includeLocal: false,
        });
        genreTracks = genreResults.tracks;
      }

      // Combine and remove the original track
      const similarTracks = [...artistTracks.tracks, ...genreTracks]
        .filter(track => track.id !== trackId && track.deezerId !== baseTrack.deezerId);

      const uniqueTracks = this.removeDuplicateTracks(similarTracks).slice(0, limit);

      return {
        recommended: uniqueTracks,
        reason: `Similar to "${baseTrack.title}" by ${baseTrack.artist}`,
        basedOn: {
          type: 'track_similarity',
          data: {
            trackId,
            title: baseTrack.title,
            artist: baseTrack.artist,
            genres: baseTrack.genres,
          },
        },
      };

    } catch (error) {
      this.logger.error(`Similar tracks error for ${trackId}:`, error);
      return this.getPopularTracks(limit);
    }
  }

  async getTopTracks(limit = 25): Promise<SearchResult> {
    try {
      const deezerResults = await this.deezerService.getTopTracks(limit);
      
      const tracks = deezerResults.data.map(deezerTrack => 
        this.convertDeezerTrackForSearch(deezerTrack)
      );

      return {
        tracks,
        total: deezerResults.total,
        source: 'deezer',
        hasMore: false,
      };

    } catch (error) {
      this.logger.error(`Top tracks error:`, error);
      return { tracks: [], total: 0, source: 'deezer', hasMore: false };
    }
  }

  async getTracksByGenre(genre: string, limit = 25): Promise<SearchResult> {
    // This would typically map genre names to Deezer genre IDs
    const genreMap: Record<string, number> = {
      'pop': 132,
      'rock': 152,
      'hip-hop': 116,
      'electronic': 106,
      'jazz': 129,
      'classical': 98,
      'reggae': 144,
      'country': 100,
      'blues': 95,
      'folk': 109,
    };

    const genreId = genreMap[genre.toLowerCase()];
    
    if (!genreId) {
      // Fallback to search
      return this.searchTracks({ query: genre, limit, includeLocal: false });
    }

    try {
      const deezerResults = await this.deezerService.searchByGenre(genreId, limit);
      
      const tracks = deezerResults.data.map(deezerTrack => 
        this.convertDeezerTrackForSearch(deezerTrack)
      );

      return {
        tracks,
        total: deezerResults.total,
        source: 'deezer',
        hasMore: deezerResults.total > limit,
      };

    } catch (error) {
      this.logger.error(`Genre tracks error for ${genre}:`, error);
      return { tracks: [], total: 0, source: 'deezer', hasMore: false };
    }
  }

  // Helper Methods
  private async searchOnDeezer(
    query: string, 
    artist?: string, 
    album?: string, 
    limit = 25
  ) {
    if (artist || album) {
      return this.deezerService.searchAdvanced({
        track: query,
        artist,
        album,
        limit,
      });
    } else {
      return this.deezerService.searchTracks(query, limit);
    }
  }

  private async searchLocalTracks(
    query: string, 
    artist?: string, 
    album?: string, 
    limit = 25
  ): Promise<Track[]> {
    let queryBuilder = this.trackRepository.createQueryBuilder('track');

    if (query) {
      queryBuilder = queryBuilder.where('track.title LIKE :query', { query: `%${query}%` });
    }

    if (artist) {
      queryBuilder = queryBuilder.andWhere('track.artist LIKE :artist', { artist: `%${artist}%` });
    }

    if (album) {
      queryBuilder = queryBuilder.andWhere('track.album LIKE :album', { album: `%${album}%` });
    }

    return queryBuilder
      .orderBy('track.title', 'ASC')
      .take(limit)
      .getMany();
  }

  private async convertDeezerTrack(deezerTrack: DeezerTrack): Promise<Track> {
    // Check if track already exists in database
    let track = await this.trackRepository.findOne({ 
      where: { deezerId: deezerTrack.id } 
    });

    if (track) {
      return track;
    }

    // Search for YouTube link for full playback
    const youtubeUrl = await this.youtubeService.searchTrack(
      deezerTrack.title,
      deezerTrack.artist.name
    );

    // Create new track from Deezer data with YouTube URL for full playback
    track = this.trackRepository.create({
      deezerId: deezerTrack.id,
      title: deezerTrack.title,
      artist: deezerTrack.artist.name,
      album: deezerTrack.album.title,
      duration: deezerTrack.duration,
      previewUrl: youtubeUrl || deezerTrack.preview || undefined, // Prefer YouTube, fallback to Deezer preview
      albumCoverUrl: deezerTrack.album.cover,
      albumCoverSmallUrl: deezerTrack.album.cover_small,
      albumCoverMediumUrl: deezerTrack.album.cover_medium,
      albumCoverBigUrl: deezerTrack.album.cover_big,
      deezerUrl: deezerTrack.preview || deezerTrack.link, // Store Deezer preview URL as fallback
      releaseDate: deezerTrack.album.release_date ? new Date(deezerTrack.album.release_date) : null,
      available: true,
    });

    // Log the result
    if (youtubeUrl) {
      this.logger.debug(`Found YouTube URL for "${deezerTrack.title}" by ${deezerTrack.artist.name}: ${youtubeUrl}`);
    } else {
      this.logger.warn(`No YouTube URL found for "${deezerTrack.title}" by ${deezerTrack.artist.name}, using Deezer preview`);
    }

    // Save and return
    return this.trackRepository.save(track);
  }

  /**
   * Convert Deezer track for search results - keeps original Deezer preview URL for 30s previews
   */
  private convertDeezerTrackForSearch(deezerTrack: DeezerTrack): Track {
    // Create track object without saving to database (for search preview only)
    return {
      id: `deezer-${deezerTrack.id}`, // Temporary ID for frontend
      deezerId: deezerTrack.id,
      title: deezerTrack.title,
      artist: deezerTrack.artist.name,
      album: deezerTrack.album.title,
      duration: deezerTrack.duration,
      previewUrl: deezerTrack.preview, // Keep Deezer preview URL for 30s previews
      albumCoverUrl: deezerTrack.album.cover,
      albumCoverSmallUrl: deezerTrack.album.cover_small,
      albumCoverMediumUrl: deezerTrack.album.cover_medium,
      albumCoverBigUrl: deezerTrack.album.cover_big,
      deezerUrl: deezerTrack.link,
      releaseDate: deezerTrack.album.release_date ? new Date(deezerTrack.album.release_date) : null,
      available: true,
      createdAt: new Date(),
      updatedAt: new Date()
    } as Track;
  }

  private combineAndDeduplicateTracks(localTracks: Track[], deezerTracks: Track[]): Track[] {
    const combined = [...localTracks];
    const existingTitles = new Set(
      localTracks.map(t => `${t.title.toLowerCase()}-${t.artist.toLowerCase()}`)
    );

    for (const deezerTrack of deezerTracks) {
      const key = `${deezerTrack.title.toLowerCase()}-${deezerTrack.artist.toLowerCase()}`;
      if (!existingTitles.has(key)) {
        combined.push(deezerTrack);
        existingTitles.add(key);
      }
    }

    return combined;
  }

  private removeDuplicateTracks(tracks: Track[]): Track[] {
    const seen = new Set<string>();
    return tracks.filter(track => {
      const key = `${track.title.toLowerCase()}-${track.artist.toLowerCase()}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  private async getPopularTracks(limit = 25): Promise<TrackRecommendations> {
    const topTracks = await this.getTopTracks(limit);
    
    return {
      recommended: topTracks.tracks,
      reason: 'Popular tracks on Deezer',
      basedOn: {
        type: 'genre',
        data: { source: 'deezer_top_chart' },
      },
    };
  }

  // Analytics and Stats
  async getTrackStats(trackId: string): Promise<any> {
    const track = await this.getTrackById(trackId);
    
    if (!track) {
      throw new NotFoundException('Track not found');
    }

    // Get additional stats from Deezer if available
    let deezerStats: any = null;
    if (track.deezerId) {
      const deezerTrack = await this.deezerService.getTrack(track.deezerId);
      if (deezerTrack) {
        deezerStats = {
          rank: deezerTrack.rank,
          explicitLyrics: deezerTrack.explicit_lyrics,
        };
      }
    }

    return {
      track,
      stats: {
        duration: track.duration,
        available: track.available,
        hasPreview: !!track.previewUrl,
        ...deezerStats,
      },
      lastUpdated: track.updatedAt,
    };
  }

  async getMusicGenres(): Promise<any[]> {
    return this.deezerService.getGenres();
  }

  // Cache management
  async clearMusicCache(): Promise<void> {
    await this.deezerService.clearCache();
    this.logger.log('Music cache cleared');
  }

  /**
   * Get or create track from Deezer data - ensures YouTube search is performed
   */
  async getOrCreateTrackFromDeezer(deezerTrack: DeezerTrack): Promise<Track> {
    this.logger.debug(`🎵 getOrCreateTrackFromDeezer called for: "${deezerTrack.title}" by ${deezerTrack.artist.name}`);
    return this.convertDeezerTrack(deezerTrack);
  }
}
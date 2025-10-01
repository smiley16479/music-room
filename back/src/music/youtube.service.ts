import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { Cache } from 'cache-manager';
import { Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { firstValueFrom } from 'rxjs';

export interface YouTubeSearchResult {
  videoId: string;
  title: string;
  channelTitle: string;
  description: string;
  thumbnails: {
    default: string;
    medium: string;
    high: string;
  };
  duration: string;
  publishedAt: string;
}

@Injectable()
export class YouTubeService {
  private readonly logger = new Logger(YouTubeService.name);
  private readonly baseUrl = 'https://www.googleapis.com/youtube/v3';
  private readonly apiKey: string;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {
    this.apiKey = this.configService.get<string>('YOUTUBE_API_KEY') || '';
    if (!this.apiKey) {
      this.logger.warn(
        'YouTube API key not configured. YouTube functionality will be disabled. ' +
        'Please set YOUTUBE_API_KEY environment variable.'
      );
    } else {
      this.logger.log('YouTube service initialized with API key');
    }
  }

  /**
   * Search for a track on YouTube using title and artist
   */
  async searchTrack(title: string, artist: string): Promise<string | null> {
    if (!this.apiKey) {
      this.logger.warn('YouTube API key not configured');
      return null;
    }

    const query = `${title} ${artist}`.trim();
    const cacheKey = `youtube:search:${query}`;

    try {
      // Check cache first
      const cached = await this.cacheManager.get<string>(cacheKey);
      if (cached) {
        this.logger.debug(`Cache hit for YouTube search: ${query}`);
        return cached;
      }

      const searchUrl = `${this.baseUrl}/search`;
      
      this.logger.debug(`Searching YouTube for: "${query}"`);
      
      const response = await firstValueFrom(
        this.httpService.get(searchUrl, {
          params: {
            part: 'snippet',
            q: query,
            type: 'video',
            videoCategoryId: '10', // Music category
            maxResults: 1,
            key: this.apiKey,
          },
          headers: {
            'User-Agent': 'MusicRoom-Backend/1.0',
            'Referer': 'https://your-domain.com', // Add your domain here
          },
        })
      );

      const items = response.data.items || [];
      if (items.length === 0) {
        this.logger.debug(`No YouTube results found for: ${query}`);
        return null;
      }

      const videoId = items[0].id.videoId;
      const youtubeUrl = `https://www.youtube.com/watch?v=${videoId}`;

      // Cache result for 24 hours
      await this.cacheManager.set(cacheKey, youtubeUrl, 86400);
      
      this.logger.debug(`Found YouTube video for "${query}": ${youtubeUrl}`);
      return youtubeUrl;

    } catch (error) {
      this.logger.error(`YouTube search error for "${query}":`, this.handleError(error));
      return null;
    }
  }

  /**
   * Get video details from YouTube
   */
  async getVideoDetails(videoId: string): Promise<YouTubeSearchResult | null> {
    if (!this.apiKey) {
      return null;
    }

    const cacheKey = `youtube:video:${videoId}`;

    try {
      const cached = await this.cacheManager.get<YouTubeSearchResult>(cacheKey);
      if (cached) {
        return cached;
      }

      const videoUrl = `${this.baseUrl}/videos`;
      const response = await firstValueFrom(
        this.httpService.get(videoUrl, {
          params: {
            part: 'snippet,contentDetails',
            id: videoId,
            key: this.apiKey,
          },
        })
      );

      const items = response.data.items || [];
      if (items.length === 0) {
        return null;
      }

      const video = items[0];
      const result: YouTubeSearchResult = {
        videoId: video.id,
        title: video.snippet.title,
        channelTitle: video.snippet.channelTitle,
        description: video.snippet.description,
        thumbnails: {
          default: video.snippet.thumbnails.default?.url || '',
          medium: video.snippet.thumbnails.medium?.url || '',
          high: video.snippet.thumbnails.high?.url || '',
        },
        duration: video.contentDetails.duration,
        publishedAt: video.snippet.publishedAt,
      };

      // Cache for 1 hour
      await this.cacheManager.set(cacheKey, result, 3600);
      
      return result;

    } catch (error) {
      this.logger.error(`YouTube video details error for ${videoId}:`, this.handleError(error));
      return null;
    }
  }

  /**
   * Extract video ID from YouTube URL
   */
  extractVideoIdFromUrl(url: string): string | null {
    const patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
      /youtube\.com\/watch\?.*v=([^&\n?#]+)/,
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        return match[1];
      }
    }

    return null;
  }

  /**
   * Build YouTube URL from video ID
   */
  buildVideoUrl(videoId: string): string {
    return `https://www.youtube.com/watch?v=${videoId}`;
  }

  private handleError(error: any): string {
    if (error?.response?.data?.error) {
      const apiError = error.response.data.error;
      this.logger.error(
        `YouTube API Error - Code: ${apiError.code}, Message: ${apiError.message}`,
        JSON.stringify(apiError, null, 2)
      );
      return `YouTube API Error: ${apiError.message}`;
    }
    this.logger.error('Unknown YouTube API error:', error?.message || error);
    return error?.message || 'Unknown YouTube API error';
  }

  // Cache Management
  async clearCache(pattern?: string): Promise<void> {
    // This would need to be implemented based on your cache manager
    // For now, just log the action
    this.logger.debug(`YouTube cache clear requested${pattern ? ` for pattern: ${pattern}` : ''}`);
  }
}

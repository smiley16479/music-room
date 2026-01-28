import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { Cache } from 'cache-manager';
import { Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { firstValueFrom } from 'rxjs';
import { Response } from 'express';
import axios from 'axios';
import { spawn } from 'child_process';

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

export interface AudioStreamResult {
  audioUrl: string;
  expiresAt: number;
  format: string;
  quality: string;
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

  /**
   * Get audio stream URL from YouTube video URL or video ID
   * This uses a fallback approach without ytdl-core
   */
  async getAudioStreamUrl(urlOrVideoId: string): Promise<AudioStreamResult | null> {
    try {
      // Extract video ID if a full URL was provided
      let videoId = urlOrVideoId;
      if (urlOrVideoId.includes('youtube.com') || urlOrVideoId.includes('youtu.be')) {
        videoId = this.extractVideoIdFromUrl(urlOrVideoId) || urlOrVideoId;
      }

      if (!videoId) {
        this.logger.warn('Invalid YouTube URL or video ID');
        return null;
      }

      const cacheKey = `youtube:audio:${videoId}`;

      // Check cache first
      const cached = await this.cacheManager.get<AudioStreamResult>(cacheKey);
      if (cached && cached.expiresAt > Date.now()) {
        this.logger.debug(`Cache hit for YouTube audio stream: ${videoId}`);
        return cached;
      }

      const youtubeUrl = this.buildVideoUrl(videoId);
      this.logger.debug(`Fetching audio stream for: ${youtubeUrl}`);

      // For now, return null and rely on proxy method instead
      // The proxy will handle the actual streaming
      return null;

    } catch (error) {
      this.logger.error(`Failed to get audio stream: ${this.handleError(error)}`);
      return null;
    }
  }

  /**
   * Search for a track and get its audio stream URL in one call
   */
  async searchAndGetAudioStream(title: string, artist: string): Promise<AudioStreamResult | null> {
    const youtubeUrl = await this.searchTrack(title, artist);
    if (!youtubeUrl) {
      return null;
    }
    return this.getAudioStreamUrl(youtubeUrl);
  }

  /**
   * Proxy YouTube audio stream through the backend using yt-dlp
   * This bypasses CORS restrictions by streaming audio through the server
   */
  async proxyAudioStream(urlOrVideoId: string, res: Response): Promise<void> {
    try {
      // Extract video ID if a full URL was provided
      let videoId = urlOrVideoId;
      if (urlOrVideoId.includes('youtube.com') || urlOrVideoId.includes('youtu.be')) {
        videoId = this.extractVideoIdFromUrl(urlOrVideoId) || urlOrVideoId;
      }

      if (!videoId) {
        res.status(400).json({ error: 'Invalid YouTube URL or video ID' });
        return;
      }

      const youtubeUrl = this.buildVideoUrl(videoId);
      this.logger.debug(`Proxying audio from YouTube using yt-dlp: ${youtubeUrl}`);

      // Set response headers for audio streaming
      res.setHeader('Content-Type', 'audio/mp4');
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      res.setHeader('Cache-Control', 'public, max-age=3600');
      res.setHeader('Transfer-Encoding', 'chunked');

      // Use yt-dlp to extract and stream audio directly
      // -f bestaudio: select best available audio format
      // -o -: output to stdout
      // --no-playlist: don't download playlist
      // --quiet: suppress output except errors
      // --extractor-args: use android client to bypass age restrictions and some blocks
      const ytDlp = spawn('yt-dlp', [
        '-f', 'bestaudio/best',
        '-o', '-',
        '--no-playlist',
        '--quiet',
        '--no-warnings',
        '--extractor-args', 'youtube:player_client=android',
        '--user-agent', 'Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        '--geo-bypass',
        '--no-check-certificates',
        youtubeUrl
      ]);

      // Pipe yt-dlp stdout directly to the response
      ytDlp.stdout.pipe(res);

      // Handle errors from yt-dlp
      ytDlp.stderr.on('data', (data) => {
        const errorMsg = data.toString();
        this.logger.warn(`yt-dlp stderr: ${errorMsg}`);
      });

      ytDlp.on('error', (error) => {
        this.logger.error(`yt-dlp process error: ${error.message}`);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Failed to extract audio from YouTube' });
        }
      });

      ytDlp.on('close', (code) => {
        if (code !== 0 && code !== null) {
          this.logger.warn(`yt-dlp exited with code ${code}`);
          if (!res.headersSent) {
            res.status(500).json({ error: 'YouTube audio extraction failed' });
          }
        } else {
          this.logger.debug('yt-dlp stream completed successfully');
        }
      });

      // Handle client disconnect
      res.on('close', () => {
        this.logger.debug('Client disconnected, killing yt-dlp process');
        ytDlp.kill('SIGTERM');
      });

    } catch (error) {
      this.logger.error(`Failed to proxy audio stream: ${this.handleError(error)}`);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to proxy audio stream' });
      }
    }
  }

  /**
   * Proxy Deezer preview audio through the backend
   */
  async proxyDeezerAudio(deezerUrl: string, res: Response): Promise<void> {
    try {
      this.logger.debug(`Proxying Deezer audio from: ${deezerUrl}`);

      const response = await axios.get(deezerUrl, {
        responseType: 'stream',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.deezer.com',
        },
        timeout: 30000,
      });

      // Set headers for audio streaming
      res.setHeader('Content-Type', 'audio/mpeg');
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cache-Control', 'no-cache');
      
      if (response.headers['content-length']) {
        res.setHeader('Content-Length', response.headers['content-length']);
      }

      response.data.pipe(res);

      response.data.on('error', (error) => {
        this.logger.error(`Deezer stream error: ${error.message}`);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Stream error' });
        } else {
          res.end();
        }
      });

      res.on('close', () => {
        this.logger.debug('Deezer audio stream closed by client');
        response.data.destroy();
      });

    } catch (error) {
      this.logger.error(`Failed to proxy Deezer audio: ${this.handleError(error)}`);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to proxy audio stream' });
      }
    }
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

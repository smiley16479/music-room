import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';

import { MusicService } from './music.service';
import { DeezerService } from './deezer.service';
import { SearchTrackDto } from './dto/search-track.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';

import { User } from 'src/user/entities/user.entity';
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';

@ApiTags('Music')
@Controller('music')
export class MusicController {
  constructor(
    private readonly musicService: MusicService,
    private readonly deezerService: DeezerService,
  ) {}

  @Get('search')
  @Public()
  @ApiOperation({
    summary: 'Search tracks',
    description: 'Search for music tracks by query, artist, album, etc.',
  })
  @ApiQuery({ type: SearchTrackDto })
  async search(@Query() searchDto: SearchTrackDto) {
    const results = await this.musicService.searchTracks(searchDto);
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('search/advanced')
  @Public()
  @ApiOperation({
    summary: 'Advanced music search',
    description: 'Search for music with multiple filters and criteria',
  })
  @ApiQuery({ 
    name: 'artist', 
    type: String, 
    required: false,
    description: 'Filter by artist name'
  })
  @ApiQuery({ 
    name: 'album', 
    type: String, 
    required: false,
    description: 'Filter by album name'
  })
  @ApiQuery({ 
    name: 'track', 
    type: String, 
    required: false,
    description: 'Filter by track name'
  })
  @ApiQuery({ 
    name: 'genre', 
    type: String, 
    required: false,
    description: 'Filter by music genre'
  })
  @ApiQuery({ 
    name: 'durationMin', 
    type: Number, 
    required: false,
    description: 'Minimum track duration in seconds'
  })
  @ApiQuery({ 
    name: 'durationMax', 
    type: Number, 
    required: false,
    description: 'Maximum track duration in seconds'
  })
  @ApiQuery({ 
    name: 'year', 
    type: Number, 
    required: false,
    description: 'Filter by release year'
  })
  @ApiQuery({ 
    name: 'limit', 
    type: Number, 
    required: false,
    description: 'Maximum number of results to return'
  })
  async advancedSearch(@Query() params: {
    artist?: string;
    album?: string;
    track?: string;
    genre?: string;
    durationMin?: number;
    durationMax?: number;
    year?: number;
    limit?: number;
  }) {
    const results = await this.musicService.searchAdvanced(params);
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('top')
  @Public()
  @ApiOperation({
    summary: 'Get top tracks',
    description: 'Returns the most popular tracks',
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of tracks to return',
    required: false,
    example: '25'
  })
  async getTopTracks(@Query('limit') limit: string = '25') {
    const results = await this.musicService.getTopTracks(parseInt(limit, 10));
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('genres')
  @Public()
  @ApiOperation({
    summary: 'Get music genres',
    description: 'Returns a list of available music genres',
  })
  async getGenres() {
    const genres = await this.musicService.getMusicGenres();
    return {
      success: true,
      data: genres,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('genre/:genre')
  @Public()
  @ApiOperation({
    summary: 'Get tracks by genre',
    description: 'Returns tracks filtered by a specific music genre',
  })
  @ApiParam({
    name: 'genre',
    type: String,
    description: 'The music genre to filter by',
    required: true,
    example: 'rock'
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of tracks to return',
    required: false,
    example: '25'
  })
  async getTracksByGenre(
    @Param('genre') genre: string,
    @Query('limit') limit: string = '25',
  ) {
    const results = await this.musicService.getTracksByGenre(genre, parseInt(limit, 10));
    return {
      success: true,
      data: results,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('track/:id')
  @Public()
  @ApiOperation({
    summary: 'Get track by ID',
    description: 'Returns detailed information about a specific track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the track to retrieve',
    required: true
  })
  async getTrack(@Param('id') id: string) {
    const track = await this.musicService.getTrackById(id);
    return {
      success: true,
      data: track,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('track/:id/stats')
  @Public()
  @ApiOperation({
    summary: 'Get track statistics',
    description: 'Returns play count, ratings, and other statistics for a track',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the track',
    required: true
  })
  async getTrackStats(@Param('id') id: string) {
    const stats = await this.musicService.getTrackStats(id);
    return {
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('track/:id/similar')
  @Public()
  @ApiOperation({
    summary: 'Get similar tracks',
    description: 'Returns tracks similar to the specified track based on genre, artist, or other factors',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the track to find similar tracks for',
    required: true
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of similar tracks to return',
    required: false,
    example: '25'
  })
  async getSimilarTracks(
    @Param('id') id: string,
    @Query('limit') limit: string = '25',
  ) {
    const recommendations = await this.musicService.getSimilarTracks(id, parseInt(limit, 10));
    return {
      success: true,
      data: recommendations,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('tracks/batch')
  @Public()
  @ApiOperation({
    summary: 'Get multiple tracks',
    description: 'Returns information for multiple tracks by their IDs',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        trackIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of track IDs to retrieve',
          example: ['track1', 'track2', 'track3']
        }
      },
      required: ['trackIds']
    }
  })
  async getMultipleTracks(@Body() { trackIds }: { trackIds: string[] }) {
    const tracks = await this.musicService.getMultipleTracks(trackIds);
    return {
      success: true,
      data: tracks,
      timestamp: new Date().toISOString(),
    };
  }

  // User-specific endpoints
  @Get('recommendations')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Get personalized recommendations',
    description: 'Returns track recommendations tailored to the current user\'s preferences and listening history',
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of recommendations to return',
    required: false,
    example: '25'
  })
  async getRecommendations(
    @Query('limit') limit: string = '25',
    @CurrentUser() user: User,
  ) {
    const recommendations = await this.musicService.getRecommendationsForUser(
      user.id,
      parseInt(limit, 10),
    );
    return {
      success: true,
      data: recommendations,
      timestamp: new Date().toISOString(),
    };
  }

  // Deezer-specific endpoints
  @Get('deezer/track/:id')
  @Public()
  @ApiOperation({
    summary: 'Get Deezer track',
    description: 'Returns track information from Deezer API',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The Deezer track ID',
    required: true
  })
  async getDeezerTrack(@Param('id') id: string) {
    const track = await this.deezerService.getTrack(id);
    return {
      success: true,
      data: track,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('deezer/album/:id')
  @Public()
  @ApiOperation({
    summary: 'Get Deezer album',
    description: 'Returns album information from Deezer API',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The Deezer album ID',
    required: true
  })
  async getDeezerAlbum(@Param('id') id: string) {
    const album = await this.deezerService.getAlbum(id);
    return {
      success: true,
      data: album,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('deezer/artist/:id')
  @Public()
  @ApiOperation({
    summary: 'Get Deezer artist',
    description: 'Returns artist information from Deezer API',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The Deezer artist ID',
    required: true
  })
  async getDeezerArtist(@Param('id') id: string) {
    const artist = await this.deezerService.getArtist(id);
    return {
      success: true,
      data: artist,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('deezer/artist/:id/top')
  @Public()
  @ApiOperation({
    summary: 'Get artist top tracks from Deezer',
    description: 'Returns the most popular tracks by an artist from Deezer API',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The Deezer artist ID',
    required: true
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of top tracks to return',
    required: false,
    example: '25'
  })
  async getArtistTopTracks(
    @Param('id') id: string,
    @Query('limit') limit: string = '25',
  ) {
    const tracks = await this.deezerService.getArtistTopTracks(id, parseInt(limit, 10));
    return {
      success: true,
      data: tracks,
      timestamp: new Date().toISOString(),
    };
  }

  // Admin endpoints
  @Post('cache/clear')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Clear music cache',
    description: 'Clears the music service cache (admin function)',
  })
  async clearCache(@CurrentUser() user: User) {
    // Add admin check here if needed
    await this.musicService.clearMusicCache();
    return {
      success: true,
      message: 'Music cache cleared successfully',
      timestamp: new Date().toISOString(),
    };
  }
}

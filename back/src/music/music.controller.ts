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

@Controller('music')
export class MusicController {
  constructor(
    private readonly musicService: MusicService,
    private readonly deezerService: DeezerService,
  ) {}

  @Get('search')
  @Public()
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

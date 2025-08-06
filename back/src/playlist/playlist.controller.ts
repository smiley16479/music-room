import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';

import { PlaylistService } from './playlist.service';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { AddTrackToPlaylistDto } from './dto/add-track.dto';
import { ReorderTracksDto } from './dto/reorder-tracks.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';

import { User } from 'src/user/entities/user.entity';

@Controller('playlists')
@UseGuards(JwtAuthGuard)
export class PlaylistController {
  constructor(private readonly playlistService: PlaylistService) {}

  @Post()
  async create(@Body() createPlaylistDto: CreatePlaylistDto, @CurrentUser() user: User) {
    const playlist = await this.playlistService.create(createPlaylistDto, user.id);
    return {
      success: true,
      message: 'Playlist created successfully',
      data: playlist,
      timestamp: new Date().toISOString(),
    };
  }

  @Get()
  @Public()
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user?: User) {
    return this.playlistService.findAll(paginationDto, user?.id);
  }

  @Get('search')
  @Public()
  async search(
    @Query('q') query: string,
    @Query('limit') limit: string = '20',
    @CurrentUser() user?: User,
  ) {
    const playlists = await this.playlistService.searchPlaylists(
      query,
      user?.id,
      parseInt(limit, 10),
    );
    return playlists;
  }

  @Get('recommended')
  async getRecommended(
    @Query('limit') limit: string = '20',
    @CurrentUser() user: User,
  ) {
    return this.playlistService.getRecommendedPlaylists(
      user.id,
      parseInt(limit, 10),
    );
  }

  @Get('my-playlists')
  async getMyPlaylists(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    // This could be a separate method in the service for user's playlists only
    return this.playlistService.findAll(paginationDto, user.id);
  }

  @Get(':id')
  @Public()
  async findOne(@Param('id') id: string, @CurrentUser() user?: User) {
    const playlist = await this.playlistService.findById(id, user?.id);
    return {
      success: true,
      data: playlist,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/tracks')
  @Public()
  async getPlaylistTracks(@Param('id') id: string, @CurrentUser() user?: User) {
    const tracks = await this.playlistService.getPlaylistTracks(id, user?.id);
    return {
      success: true,
      data: tracks,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/collaborators')
  @Public()
  async getCollaborators(@Param('id') id: string, @CurrentUser() user?: User) {
    const collaborators = await this.playlistService.getCollaborators(id, user?.id);
    return {
      success: true,
      data: collaborators,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updatePlaylistDto: UpdatePlaylistDto,
    @CurrentUser() user: User,
  ) {
    const playlist = await this.playlistService.update(id, updatePlaylistDto, user.id);
    return {
      success: true,
      message: 'Playlist updated successfully',
      data: playlist,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.playlistService.remove(id, user.id);
    return {
      success: true,
      message: 'Playlist deleted successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Track Management
  @Post(':id/tracks')
  @HttpCode(HttpStatus.OK)
  async addTrack(
    @Param('id') id: string,
    @Body() addTrackDto: AddTrackToPlaylistDto,
    @CurrentUser() user: User,
  ) {
    const track = await this.playlistService.addTrack(id, user.id, addTrackDto);
    return {
      success: true,
      message: 'Track added to playlist successfully',
      data: track,
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/tracks/:trackId')
  async removeTrack(
    @Param('id') id: string,
    @Param('trackId') trackId: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistService.removeTrack(id, trackId, user.id);
    return {
      success: true,
      message: 'Track removed from playlist successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id/tracks/reorder')
  @HttpCode(HttpStatus.OK)
  async reorderTracks(
    @Param('id') id: string,
    @Body() reorderDto: ReorderTracksDto,
    @CurrentUser() user: User,
  ) {
    const tracks = await this.playlistService.reorderTracks(id, user.id, reorderDto);
    return {
      success: true,
      message: 'Tracks reordered successfully',
      data: tracks,
      timestamp: new Date().toISOString(),
    };
  }

  // Collaborator Management
  @Post(':id/collaborators/:userId')
  @HttpCode(HttpStatus.OK)
  async addCollaborator(
    @Param('id') id: string,
    @Param('userId') collaboratorId: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistService.addCollaborator(id, collaboratorId, user.id);
    return {
      success: true,
      message: 'Collaborator added successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Delete(':id/collaborators/:userId')
  async removeCollaborator(
    @Param('id') id: string,
    @Param('userId') collaboratorId: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistService.removeCollaborator(id, collaboratorId, user.id);
    return {
      success: true,
      message: 'Collaborator removed successfully',
      timestamp: new Date().toISOString(),
    };
  }

  // Advanced Features
  @Post(':id/duplicate')
  @HttpCode(HttpStatus.OK)
  async duplicatePlaylist(
    @Param('id') id: string,
    @Body() { name }: { name?: string },
    @CurrentUser() user: User,
  ) {
    const duplicatedPlaylist = await this.playlistService.duplicatePlaylist(id, user.id, name);
    return {
      success: true,
      message: 'Playlist duplicated successfully',
      data: duplicatedPlaylist,
      timestamp: new Date().toISOString(),
    };
  }

  @Get(':id/export')
  async exportPlaylist(@Param('id') id: string, @CurrentUser() user: User) {
    const exportData = await this.playlistService.exportPlaylist(id, user.id);
    return {
      success: true,
      data: exportData,
      timestamp: new Date().toISOString(),
    };
  }

  @Post(':id/invite')
  @HttpCode(HttpStatus.OK)
  async inviteCollaborators(
    @Param('id') id: string,
    @Body() { emails }: { emails: string[] },
    @CurrentUser() user: User,
  ) {
    await this.playlistService.inviteCollaborators(id, user.id, emails);
    return {
      success: true,
      message: 'Invitations sent successfully',
      timestamp: new Date().toISOString(),
    };
  }
}
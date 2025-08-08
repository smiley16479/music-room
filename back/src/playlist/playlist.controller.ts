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
import { ApiTags, ApiOperation, ApiBody, ApiParam, ApiQuery } from '@nestjs/swagger';

@ApiTags('Playlists')
@Controller('playlists')
@UseGuards(JwtAuthGuard)
export class PlaylistController {
  constructor(private readonly playlistService: PlaylistService) {}

  @Post()
  @ApiOperation({
    summary: 'Create playlist',
    description: 'Creates a new playlist owned by the current user',
  })
  @ApiBody({ type: CreatePlaylistDto })
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
  @ApiOperation({
    summary: 'Get all playlists',
    description: 'Returns a paginated list of public playlists and those owned by the current user',
  })
  @ApiQuery({ type: PaginationDto })
  async findAll(@Query() paginationDto: PaginationDto, @CurrentUser() user?: User) {
    return this.playlistService.findAll(paginationDto, user?.id);
  }

  @Get('search')
  @Public()
  @ApiOperation({
    summary: 'Search playlists',
    description: 'Search for playlists by name, description, or tags',
  })
  @ApiQuery({ 
    name: 'q', 
    type: String, 
    description: 'Search query string',
    required: true,
    example: 'summer hits'
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of results to return',
    required: false,
    example: '20'
  })
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
  @ApiOperation({
    summary: 'Get recommended playlists',
    description: 'Returns playlists recommended for the current user based on their preferences',
  })
  @ApiQuery({ 
    name: 'limit', 
    type: String, 
    description: 'Maximum number of recommendations to return',
    required: false,
    example: '20'
  })
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
  @ApiOperation({
    summary: 'Get my playlists',
    description: 'Returns all playlists owned by the current user',
  })
  @ApiQuery({ type: PaginationDto })
  async getMyPlaylists(@Query() paginationDto: PaginationDto, @CurrentUser() user: User) {
    // This could be a separate method in the service for user's playlists only
    return this.playlistService.findAll(paginationDto, user.id);
  }

  @Get(':id')
  @Public()
  @ApiOperation({
    summary: 'Get playlist by ID',
    description: 'Returns detailed information about a specific playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist to retrieve',
    required: true
  })
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
  @ApiOperation({
    summary: 'Get playlist tracks',
    description: 'Returns all tracks in a specific playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
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
  @ApiOperation({
    summary: 'Get playlist collaborators',
    description: 'Returns all users who have collaborative access to a playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  async getCollaborators(@Param('id') id: string, @CurrentUser() user?: User) {
    const collaborators = await this.playlistService.getCollaborators(id, user?.id);
    return {
      success: true,
      data: collaborators,
      timestamp: new Date().toISOString(),
    };
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update playlist',
    description: 'Updates playlist information such as name, description, or privacy settings',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist to update',
    required: true
  })
  @ApiBody({ type: UpdatePlaylistDto })
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
  @ApiOperation({
    summary: 'Delete playlist',
    description: 'Permanently deletes a playlist and all its tracks',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist to delete',
    required: true
  })
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
  @ApiOperation({
    summary: 'Add track to playlist',
    description: 'Adds a new track to the specified playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiBody({ type: AddTrackToPlaylistDto })
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
  @ApiOperation({
    summary: 'Remove track from playlist',
    description: 'Removes a specific track from the playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiParam({
    name: 'trackId',
    type: String,
    description: 'The ID of the track to remove',
    required: true
  })
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
  @ApiOperation({
    summary: 'Reorder playlist tracks',
    description: 'Changes the order of tracks in a playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiBody({ type: ReorderTracksDto })
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
  @ApiOperation({
    summary: 'Add playlist collaborator',
    description: 'Adds a user as a collaborator to the playlist, giving them edit permissions',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the user to add as collaborator',
    required: true
  })
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
  @ApiOperation({
    summary: 'Remove playlist collaborator',
    description: 'Removes a user\'s collaborative access to the playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiParam({
    name: 'userId',
    type: String,
    description: 'The ID of the user to remove as collaborator',
    required: true
  })
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
  @ApiOperation({
    summary: 'Duplicate playlist',
    description: 'Creates a copy of an existing playlist with all its tracks',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist to duplicate',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Optional name for the duplicated playlist',
          example: 'My Playlist Copy'
        }
      }
    }
  })
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
  @ApiOperation({
    summary: 'Export playlist',
    description: 'Exports playlist data for backup or sharing purposes',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist to export',
    required: true
  })
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
  @ApiOperation({
    summary: 'Invite collaborators to playlist',
    description: 'Sends email invitations to multiple users to collaborate on a playlist',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        emails: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of email addresses to invite',
          example: ['friend1@example.com', 'friend2@example.com']
        }
      },
      required: ['emails']
    }
  })
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
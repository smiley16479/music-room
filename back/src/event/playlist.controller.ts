import {
  Controller,
  Post,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';

import { EventService } from './event.service';
import { AddTrackToPlaylistDto } from './dto/playlist/add-track.dto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { User } from 'src/user/entities/user.entity';
import { ApiTags, ApiOperation, ApiBody, ApiParam } from '@nestjs/swagger';

@ApiTags('Playlists')
@Controller('playlists')
@UseGuards(JwtAuthGuard)
export class PlaylistController {
  constructor(private readonly eventService: EventService) {}

  @Post(':id/tracks')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Add track to playlist',
    description: 'Adds a track to the playlist. Only creator or admins can add tracks.',
  })
  @ApiParam({
    name: 'id',
    type: String,
    description: 'The ID of the playlist',
    required: true
  })
  @ApiBody({ type: AddTrackToPlaylistDto })
  async addTrackToPlaylist(
    @Param('id') playlistId: string,
    @Body() addTrackDto: AddTrackToPlaylistDto,
    @CurrentUser() user: User,
  ) {
    const playlistTrack = await this.eventService.addTrack(playlistId, user.id, addTrackDto);
    return {
      success: true,
      message: 'Track added to playlist successfully',
      data: playlistTrack,
      timestamp: new Date().toISOString(),
    };
  }
}

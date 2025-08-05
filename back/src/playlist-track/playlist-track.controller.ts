import { Controller, Get, Post, Body, Patch, Param, Delete } from '@nestjs/common';
import { PlaylistTrackService } from './playlist-track.service';
import { CreatePlaylistTrackDto } from './dto/create-playlist-track.dto';
import { UpdatePlaylistTrackDto } from './dto/update-playlist-track.dto';

@Controller('playlist-track')
export class PlaylistTrackController {
  constructor(private readonly playlistTrackService: PlaylistTrackService) {}

  @Post()
  create(@Body() createPlaylistTrackDto: CreatePlaylistTrackDto) {
    return this.playlistTrackService.create(createPlaylistTrackDto);
  }

  @Get()
  findAll() {
    return this.playlistTrackService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.playlistTrackService.findOne(+id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updatePlaylistTrackDto: UpdatePlaylistTrackDto) {
    return this.playlistTrackService.update(+id, updatePlaylistTrackDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.playlistTrackService.remove(+id);
  }
}

import { Module } from '@nestjs/common';
import { PlaylistTrackService } from './playlist-track.service';
import { PlaylistTrackController } from './playlist-track.controller';

@Module({
  controllers: [PlaylistTrackController],
  providers: [PlaylistTrackService],
})
export class PlaylistTrackModule {}

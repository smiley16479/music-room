import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlaylistController } from './playlist.controller';
import { PlaylistService } from './playlist.service';

import { Playlist } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

import { UserModule } from 'src/user/user.module';
import { EmailModule } from '../email/email.module';
import { AuthModule } from '../auth/auth.module';
import { EventModule } from '../event/event.module';
import { MusicModule } from '../music/music.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Playlist, PlaylistTrack, Track, User, Event, Invitation]),
    UserModule,
    EmailModule,
    AuthModule,
    MusicModule,
    forwardRef(() => EventModule),
  ],
  controllers: [PlaylistController],
  providers: [PlaylistService],
  exports: [PlaylistService],
})
export class PlaylistModule {}
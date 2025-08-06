import { Module } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlaylistController } from './playlist.controller';
import { PlaylistService } from './playlist.service';
import { PlaylistGateway } from './playlist.gateway';

import { Playlist } from 'src/playlist/entities/playlist.entity';
import { PlaylistTrack } from 'src/playlist-track/entities/playlist-track.entity';
import { Track } from 'src/track/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

import { UserModule } from 'src/user/user.module';
import { EmailModule } from '../email/email.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Playlist, PlaylistTrack, Track, User, Invitation]),
    UserModule,
    EmailModule,
  ],
  controllers: [PlaylistController],
  providers: [PlaylistService, PlaylistGateway, JwtService],
  exports: [PlaylistService],
})
export class PlaylistModule {}
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { EventController } from './event.controller';
import { EventService } from './event.service';
import { EventGateway } from './event.gateway';

import { Event } from 'src/event/entities/event.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

import { UserModule } from '../user/user.module';
import { EmailModule } from '../email/email.module';
import { PlaylistModule } from 'src/playlist/playlist.module';
import { Playlist } from 'src/playlist/entities/playlist.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Event, Vote, Track, User, Invitation, Playlist]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRES_IN', '24h'),
        },
      }),
      inject: [ConfigService],
    }),
    UserModule,
    EmailModule,
    PlaylistModule
  ],
  controllers: [EventController],
  providers: [EventService, EventGateway],
  exports: [EventService],
})
export class EventModule { }
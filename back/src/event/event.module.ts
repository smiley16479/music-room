import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

// Event imports
import { EventController } from './event.controller';
import { EventService } from './event.service';
import { EventGateway } from './event.gateway';
import { EventParticipantService } from './event-participant.service';

// Playlist imports (fusionnés dans EventModule)
import { PlaylistController } from '../playlist/playlist.controller';
import { PlaylistService } from '../playlist/playlist.service';

// Entities
import { Event } from 'src/event/entities/event.entity';
import { EventParticipant } from 'src/event/entities/event-participant.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

// External modules
import { UserModule } from '../user/user.module';
import { EmailModule } from '../email/email.module';
import { AuthModule } from '../auth/auth.module';
import { MusicModule } from '../music/music.module';
import { CommonModule } from '../common/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Event, 
      EventParticipant, 
      Vote, 
      PlaylistTrack, 
      Track, 
      User, 
      Invitation
    ]),
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
    AuthModule,
    MusicModule,
    CommonModule,
  ],
  controllers: [EventController, PlaylistController],
  providers: [EventService, EventParticipantService, EventGateway, PlaylistService],
  exports: [EventService, EventParticipantService, EventGateway, PlaylistService],
})
export class EventModule { }
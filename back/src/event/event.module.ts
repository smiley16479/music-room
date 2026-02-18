import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

// Event imports
import { EventController } from './event.controller';
import { PlaylistController } from './playlist.controller';
import { EventService } from './event.service';
import { EventStreamService } from './event-stream.service';
import { EventGateway } from './event.gateway';
import { EventParticipantService } from './event-participant.service';

// Entities
import { Event } from 'src/event/entities/event.entity';
import { EventParticipant } from 'src/event/entities/event-participant.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { PlaylistTrack } from 'src/event/entities/playlist-track.entity';
import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';

// External modules
import { UserModule } from '../user/user.module';
import { EmailModule } from '../email/email.module';
import { AuthModule } from '../auth/auth.module';
import { MusicModule } from '../music/music.module';
import { CommonModule } from '../common/common.module';
import { DeviceModule } from '../device/device.module';

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
          // cast to any to satisfy newer @nestjs/jwt types
          expiresIn: configService.get('JWT_EXPIRES_IN', '24h') as any,
        },
      }),
      inject: [ConfigService],
    }),
    UserModule,
    EmailModule,
    AuthModule,
    MusicModule,
    CommonModule,
    forwardRef(() => DeviceModule),
  ],
  controllers: [EventController, PlaylistController],
  providers: [EventService, EventStreamService, EventParticipantService, EventGateway],
  exports: [EventService, EventStreamService, EventParticipantService, EventGateway],
})
export class EventModule { }
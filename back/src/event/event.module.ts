import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';

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

@Module({
  imports: [
    TypeOrmModule.forFeature([Event, Vote, Track, User, Invitation]),
    UserModule,
    EmailModule,
  ],
  controllers: [EventController],
  providers: [EventService, EventGateway, JwtService],
  exports: [EventService],
})
export class EventModule {}
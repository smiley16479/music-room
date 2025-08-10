import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { Track } from 'src/music/entities/track.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Device } from 'src/device/entities/device.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';
import { PlaylistTrack } from 'src/playlist/entities/playlist-track.entity';
import { DatabaseController } from './database.controller';
import { DatabaseService } from './database.service';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'mysql',
        host: configService.get('DB_HOST', 'db'),
        port: configService.get('DB_PORT', 3306),
        username: configService.get('DB_USERNAME', 'root'),
        password: configService.get('DB_PASSWORD', 'root'),
        database: configService.get('DB_DATABASE', 'db'),
        entities: [
          User,
          Event,
          Playlist,
          Track,
          Vote,
          Device,
          Invitation,
          PlaylistTrack,
        ],
        synchronize: configService.get('NODE_ENV') === 'dev',
        logging: false, //configService.get('NODE_ENV') === 'dev',
        timezone: 'Z',
        charset: 'utf8mb4',
        extra: {
          connectionLimit: 10,
          acquireTimeout: 60000,
          timeout: 60000,
        },
      }),
      inject: [ConfigService],
    }),
  ],
    // controllers: [DatabaseController],
    // providers: [DatabaseService],
})
export class DatabaseModule {}

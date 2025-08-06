import { DataSource } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { config } from 'dotenv';
import { User } from 'src/user/entities/user.entity';
import { Event } from 'src/event/entities/event.entity';
import { Playlist } from 'src/playlist/entities/playlist.entity';
import { Track } from 'src/track/entities/track.entity';
import { Vote } from 'src/event/entities/vote.entity';
import { Device } from 'src/device/entities/device.entity';
import { Invitation } from 'src/invitation/entities/invitation.entity';
import { PlaylistTrack } from 'src/playlist-track/entities/playlist-track.entity';

config();

const configService = new ConfigService();

export const AppDataSource = new DataSource({
  type: 'mysql',
  host: configService.get('DB_HOST', 'db'),
  port: configService.get('DB_PORT', 3306),
  username: configService.get('DB_USERNAME', 'root'),
  password: configService.get('DB_PASSWORD', 'root'),
  database: configService.get('DB_DATABASE', 'db'),
  synchronize: false,
  logging: configService.get('NODE_ENV') === 'dev',
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
  migrations: ['src/database/migrations/*.ts'],
  subscribers: ['src/database/subscribers/*.ts'],
  timezone: 'Z',
  charset: 'utf8mb4',
});
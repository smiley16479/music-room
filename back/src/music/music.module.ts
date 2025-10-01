import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { CacheModule } from '@nestjs/cache-manager';

import { MusicController } from './music.controller';
import { MusicService } from './music.service';
import { DeezerService } from './deezer.service';
import { YouTubeService } from './youtube.service';

import { Track } from 'src/music/entities/track.entity';
import { User } from 'src/user/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Track, User]),
    HttpModule.register({
      timeout: 10000,
      maxRedirects: 3,
    }),
    CacheModule.register({
      ttl: 300, // 5 minutes cache
      max: 1000, // Maximum 1000 items in cache
    }),
  ],
  controllers: [MusicController],
  providers: [MusicService, DeezerService, YouTubeService],
  exports: [MusicService, DeezerService, YouTubeService],
})
export class MusicModule {}
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { UserModule } from './user/user.module';
import { EventModule } from './event/event.module';
import { PlaylistModule } from './playlist/playlist.module';
import { TrackModule } from './track/track.module';
import { VoteModule } from './vote/vote.module';
import { DeviceModule } from './device/device.module';
import { InvitationModule } from './invitation/invitation.module';
import { PlaylistTrackModule } from './playlist-track/playlist-track.module';
import { DatabaseModule } from './database/database.module';
import { MailModule } from './mail/mail.module';
import { AuthModule } from './auth/auth.module';
import { APP_GUARD, APP_FILTER } from '@nestjs/core';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { AuthExceptionFilter } from './auth/filters/auth-exception.filter';
import { EmailModule } from './email/email.module';


@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const url = configService.get<string>('DATABASE_URL');
        console.log('DB URL used by TypeORM:', url);
        return {
          type: 'mysql',
          url,
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          cache: false,
          synchronize: true,
        };
      }
    }),
    UserModule,
    EventModule,
    PlaylistModule,
    TrackModule,
    VoteModule,
    DeviceModule,
    InvitationModule,
    PlaylistTrackModule,
    DatabaseModule,
    MailModule,
    AuthModule,
    EmailModule,
  ],
  controllers: [AppController],
  providers: [AppService,
    // Global JWT Guard
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    // Global Auth Exception Filter
    {
      provide: APP_FILTER,
      useClass: AuthExceptionFilter,
    },
  ],
})
export class AppModule {}

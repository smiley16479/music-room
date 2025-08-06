import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { UserModule } from './user/user.module';
import { EventModule } from './event/event.module';
import { PlaylistModule } from './playlist/playlist.module';
import { DeviceModule } from './device/device.module';
import { InvitationModule } from './invitation/invitation.module';
// import { DatabaseModule } from './database/database.module';
// import { EmailModule } from './email/email.module';
import { MailModule } from './mail/mail.module';
import { AuthModule } from './auth/auth.module';
import { APP_GUARD, APP_FILTER } from '@nestjs/core';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { AuthExceptionFilter } from './auth/filters/auth-exception.filter';
import { MusicModule } from './music/music.module';


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
    DeviceModule,
    InvitationModule,
    // DatabaseModule,
    // EmailModule,
    MailModule,
    AuthModule,
    MusicModule,
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

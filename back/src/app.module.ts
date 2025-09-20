import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { UserModule } from './user/user.module';
import { DatabaseModule } from './database/database.module';
import { MusicModule } from './music/music.module';
import { DeviceModule } from './device/device.module';
import { EmailModule } from './email/email.module';
import { EventModule } from './event/event.module';
import { PlaylistModule } from './playlist/playlist.module';
import { InvitationModule } from './invitation/invitation.module';
import { APP_GUARD, APP_FILTER } from '@nestjs/core';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { AuthExceptionFilter } from './auth/filters/auth-exception.filter';
import { PermissionsGuard } from './common/guards/permissions.guard';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '/app/.env',
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
    AuthModule,
    UserModule,
    DatabaseModule,
    MusicModule,
    DeviceModule,
    EmailModule,
    EventModule,
    PlaylistModule,
    InvitationModule,
  ],
  controllers: [AppController],
  providers: [AppService,
    // // Global JWT Guard
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    // 2. Guard de permissions (vérifie @RequirePermissions)
    {
      provide: APP_GUARD,
      useClass: PermissionsGuard,
    },
    // // Global Auth Exception Filter
    // {
    //   provide: APP_FILTER,
    //   useClass: AuthExceptionFilter,
    // },
  ],
})
export class AppModule {}

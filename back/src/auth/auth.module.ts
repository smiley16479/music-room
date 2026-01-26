import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { GoogleStrategy } from './strategies/google.strategy';
import { FacebookStrategy } from './strategies/facebook.strategy';
import { GoogleLinkStrategy } from './strategies/google-link.strategy';
import { FacebookLinkStrategy } from './strategies/facebook-link.strategy';
import { LocalStrategy } from './strategies/local.strategy';

import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import { FacebookAuthGuard } from './guards/facebook-auth.guard';
import { GoogleLinkAuthGuard } from './guards/google-link-auth.guard';
import { FacebookLinkAuthGuard } from './guards/facebook-link-auth.guard';
import { LocalAuthGuard } from './guards/local-auth.guard';

import { User } from 'src/user/entities/user.entity';
import { UserService } from 'src/user/user.service';
import { EmailService } from 'src/email/email.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    HttpModule.register({
      timeout: 10000,
      maxRedirects: 3,
    }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          // cast to any to satisfy newer @nestjs/jwt types (accepts number | StringValue)
          expiresIn: configService.get('JWT_EXPIRES_IN', '24h') as any,
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    UserService,
    EmailService,
    LocalStrategy,
    JwtStrategy,
    JwtRefreshStrategy,
    GoogleStrategy,
    FacebookStrategy,
    GoogleLinkStrategy,
    FacebookLinkStrategy,
    JwtAuthGuard,
    JwtRefreshGuard,
    GoogleAuthGuard,
    FacebookAuthGuard,
    GoogleLinkAuthGuard,
    FacebookLinkAuthGuard,
    LocalAuthGuard,
  ],
  exports: [
    AuthService,
    JwtAuthGuard,
    JwtRefreshGuard,
    PassportModule,
    JwtModule,
  ],
})

export class AuthModule {}
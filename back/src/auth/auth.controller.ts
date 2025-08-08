import {
  Controller,
  Get,
  Post,
  Body,
  Req,
  Res,
  UseGuards,
  HttpCode,
  HttpStatus,
  Query,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AuthService } from './auth.service';

import { Public } from './decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { LocalAuthGuard } from './guards/local-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import { FacebookAuthGuard } from './guards/facebook-auth.guard';

import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RequestPasswordResetDto, ResetPasswordDto } from 'src/user/dto/reset-password.dto';

import { User } from 'src/user/entities/user.entity';

import { ApiOperation, ApiBody, ApiQuery, ApiParam } from '@nestjs/swagger';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @ApiOperation({
    summary: 'Register a new user',
    description: 'Creates a new user account and sends a verification email. Optionally accepts a referral code as a query parameter.',
  })
  @ApiBody({
    type: RegisterDto,
    description: 'User registration data including email, password, and other required fields.',
    required: true,
    examples: {
      example1: {
        summary: 'Basic registration',
        value: {
          email: 'user@example.com',
          password: 'StrongPassword123!',
          displayName: 'musicfan',
        },
      },
    },
  })
  async register(@Body() registerDto: RegisterDto) {
    const result = await this.authService.register(registerDto);
    return {
      success: true,
      message: 'User registered successfully. Please check your email to verify your account.',
      data: result,
      timestamp: new Date().toISOString(),
    };
  }

  @Public()
  @UseGuards(LocalAuthGuard)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Req() req: Request & { user: User }, @Body() loginDto: LoginDto) {
    const result = await this.authService.login(loginDto);
    return {
      success: true,
      message: 'Login successful',
      data: result,
      timestamp: new Date().toISOString(),
    };
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refreshToken(@Body() refreshTokenDto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(refreshTokenDto.refreshToken);
    return {
      success: true,
      message: 'Token refreshed successfully',
      data: result,
      timestamp: new Date().toISOString(),
    };
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  async requestPasswordReset(@Body() dto: RequestPasswordResetDto) {
    await this.authService.requestPasswordReset(dto);
    return {
      success: true,
      message: 'If an account with that email exists, a password reset link has been sent.',
      timestamp: new Date().toISOString(),
    };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.authService.resetPassword(dto);
    return {
      success: true,
      message: 'Password reset successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Public()
  @Get('verify-email')
  async verifyEmail(@Query('token') token: string) {
    await this.authService.verifyEmail(token);
    return {
      success: true,
      message: 'Email verified successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('resend-verification')
  async resendVerification(@CurrentUser() user: User) {
    await this.authService.sendEmailVerification(user);
    return {
      success: true,
      message: 'Verification email sent',
      timestamp: new Date().toISOString(),
    };
  }

  // Google OAuth
  @Public()
  @Get('google')
  @UseGuards(GoogleAuthGuard)
  async googleAuth() {
    // Initiates Google OAuth flow
  }

  @Public()
  @Get('google/callback')
  @UseGuards(GoogleAuthGuard)
  async googleAuthCallback(@Req() req: Request & { user: any }, @Res() res: Response) {
    try {
      const result = await this.authService.googleLogin(req.user);
      console.log('Google login successful:', result);

      // Redirect to frontend with tokens
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const redirectUrl = `${frontendUrl}/auth/callback?` +
        `token=${result.accessToken}&` +
        `refresh=${result.refreshToken}&` +
        `success=true`;
      
      res.redirect(redirectUrl);
    } catch (error) {
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const redirectUrl = `${frontendUrl}/auth/callback?error=${encodeURIComponent(error.message)}`;
      res.redirect(redirectUrl);
    }
  }

  // Facebook OAuth
  @Public()
  @Get('facebook')
  @UseGuards(FacebookAuthGuard)
  async facebookAuth() {
    // Initiates Facebook OAuth flow
  }

  @Public()
  @Get('facebook/callback')
  @UseGuards(FacebookAuthGuard)
  async facebookAuthCallback(@Req() req: Request & { user: any }, @Res() res: Response) {
    try {
      const result = await this.authService.facebookLogin(req.user);
      
      // Redirect to frontend with tokens
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const redirectUrl = `${frontendUrl}/auth/callback?` +
        `token=${result.accessToken}&` +
        `refresh=${result.refreshToken}&` +
        `success=true`;
      
      res.redirect(redirectUrl);
    } catch (error) {
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const redirectUrl = `${frontendUrl}/auth/callback?error=${encodeURIComponent(error.message)}`;
      res.redirect(redirectUrl);
    }
  }

  @Get('me')
  async getProfile(@CurrentUser() user: User) {
    return {
      success: true,
      data: user,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(@CurrentUser() user: User) {
    // In a more advanced implementation, you might want to blacklist the token
    return {
      success: true,
      message: 'Logged out successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('link-google')
  async linkGoogle(@CurrentUser() user: User, @Body() { googleToken }: { googleToken: string }) {
    // TODO: Implement linking existing account with Google
    return {
      success: true,
      message: 'Google account linked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('link-facebook')
  async linkFacebook(@CurrentUser() user: User, @Body() { facebookToken }: { facebookToken: string }) {
    // TODO: Implement linking existing account with Facebook
    return {
      success: true,
      message: 'Facebook account linked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('unlink-google')
  async unlinkGoogle(@CurrentUser() user: User) {
    // TODO: Implement unlinking Google account
    return {
      success: true,
      message: 'Google account unlinked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('unlink-facebook')
  async unlinkFacebook(@CurrentUser() user: User) {
    // TODO: Implement unlinking Facebook account
    return {
      success: true,
      message: 'Facebook account unlinked successfully',
      timestamp: new Date().toISOString(),
    };
  }
}
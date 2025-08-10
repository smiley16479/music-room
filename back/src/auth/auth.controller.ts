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
  Logger,
  BadRequestException,
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

  private readonly logger = new Logger(AuthController.name);
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
  @ApiOperation({
    summary: 'Authenticate a user',
    description: 'Authenticate a user with email and password credentials and return access and refresh tokens',
  })
  @ApiBody({
    type: LoginDto,
    description: 'User login credentials',
    required: true,
    examples: {
      example1: {
        summary: 'Standard login',
        value: {
          email: 'user@example.com',
          password: 'YourPassword123!',
        },
      },
    },
  })
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
  @ApiOperation({
    summary: 'Refresh access token',
    description: 'Use a valid refresh token to generate a new access token when the original expires',
  })
  @ApiBody({
    type: RefreshTokenDto,
    description: 'Refresh token data',
    required: true,
    examples: {
      example1: {
        summary: 'Token refresh',
        value: {
          refreshToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        },
      },
    },
  })
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
  @ApiOperation({
    summary: 'Request password reset',
    description: 'Request a password reset link to be sent to the user\'s email',
  })
  @ApiBody({
    type: RequestPasswordResetDto,
    description: 'Email address for password reset',
    required: true,
    examples: {
      example1: {
        summary: 'Password reset request',
        value: {
          email: 'user@example.com',
        },
      },
    },
  })
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
  @ApiOperation({
    summary: 'Reset password',
    description: 'Reset the user\'s password using the token received via email',
  })
  @ApiBody({
    type: ResetPasswordDto,
    description: 'Reset password data including token and new password',
    required: true,
    examples: {
      example1: {
        summary: 'Password reset',
        value: {
          token: 'abcdef123456',
          password: 'NewStrongPassword123!',
          confirmPassword: 'NewStrongPassword123!',
        },
      },
    },
  })
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
  @ApiOperation({
    summary: 'Verify email address',
    description: 'Verify a user\'s email address using the token sent via email',
  })
  @ApiQuery({
    name: 'token',
    type: String,
    description: 'The email verification token received via email',
    required: true,
    example: 'abc123def456ghi789'
  })
  async verifyEmail(@Query('token') token: string) {
    await this.authService.verifyEmail(token);
    return {
      success: true,
      message: 'Email verified successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('resend-verification')
  @ApiOperation({
    summary: 'Resend verification email',
    description: 'Resend the email verification link to the current user\'s email address',
  })
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
  @ApiOperation({
    summary: 'Google OAuth login',
    description: 'Initiates Google OAuth authentication flow',
  })
  async googleAuth() {
    // Initiates Google OAuth flow
  }

  @Public()
  @Get('google/callback')
  @UseGuards(GoogleAuthGuard)
  @ApiOperation({
    summary: 'Google OAuth callback',
    description: 'Handles the Google OAuth callback and redirects to the frontend with authentication tokens',
  })
  async googleAuthCallback(@Req() req: Request & { user: any }, @Res() res: Response) {
    this.logger.log(`googleAuthCallback`);
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

  /** Même logique que GoogleAuthGuard mais retourne JSON */
  @Post('google/mobile-token')
  // async googleMobileTokenExchange(@Body() { code }: { code: string }) {
  async googleMobileTokenExchange(@Body() body/* { idToken }: { idToken: string } */) {
    console.log("body", body);
    
    this.logger.log(`google/mobile-token AuthCallback`);

    try {
      const googleUser = await this.authService.verifyGoogleCode(body.code);
      // const googleUser = await this.authService.verifyGoogleIdToken(bodyidToken);
      const result = await this.authService.googleLogin(googleUser);
      console.log('Google login successful:', result);
    } catch (error) {
      this.logger.error(`google/mobile-token AuthCallback`);
    }
  }

  // Facebook OAuth
  @Public()
  @Get('facebook')
  @UseGuards(FacebookAuthGuard)
  @ApiOperation({
    summary: 'Facebook OAuth login',
    description: 'Initiates Facebook OAuth authentication flow',
  })
  async facebookAuth() {
    // Initiates Facebook OAuth flow
  }

  @Public()
  @Get('facebook/callback')
  @UseGuards(FacebookAuthGuard)
  @ApiOperation({
    summary: 'Facebook OAuth callback',
    description: 'Handles the Facebook OAuth callback and redirects to the frontend with authentication tokens',
  })
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

  @Post('facebook/mobile-login')
    @ApiOperation({
      summary: 'Facebook OAuth callback for mobile',
      description: 'Handles the Facebook OAuth callback for mobile and redirects to the mobileApp with authentication tokens',
    })
  async facebookMobileLogin(@Body('access_token') fbToken: string) {

    try {
      this.logger.log(`facebookMobileLogin access_token ${fbToken}`);
      const fbProfile = await this.authService.getFacebookProfile(fbToken);

      const fbUserData = {
          id: fbProfile.id,
          email: fbProfile.email,
          name: fbProfile.name,
          picture: fbProfile.picture?.data?.url,
          accessToken: fbToken,
      };

      // const fbUserData = await this.authService.verifyFacebookToken(fbToken);
      const result = await this.authService.facebookLogin(fbUserData);
      this.logger.log(`facebookMobileLogin result`, result);
      return {
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user
      };
    } catch (error) {
        this.logger.error('Facebook mobile login failed:', error);
        throw new BadRequestException('Facebook authentication failed');
    }
  }

  @Get('me')
  @ApiOperation({
    summary: 'Get current user profile',
    description: 'Returns the profile information of the currently authenticated user',
  })
  async getProfile(@CurrentUser() user: User) {
    return {
      success: true,
      data: user,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Logout user',
    description: 'Logs out the current user from the application',
  })
  async logout(@CurrentUser() user: User) {
    // In a more advanced implementation, you might want to blacklist the token
    return {
      success: true,
      message: 'Logged out successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('link-google')
  @ApiOperation({
    summary: 'Link Google account',
    description: 'Links the current user account with a Google account',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        googleToken: {
          type: 'string',
          description: 'Google authentication token',
          example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        }
      },
      required: ['googleToken']
    }
  })
  async linkGoogle(@CurrentUser() user: User, @Body() { googleToken }: { googleToken: string }) {
    // TODO: Implement linking existing account with Google
    return {
      success: true,
      message: 'Google account linked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('link-facebook')
  @ApiOperation({
    summary: 'Link Facebook account',
    description: 'Links the current user account with a Facebook account',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        facebookToken: {
          type: 'string',
          description: 'Facebook authentication token',
          example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        }
      },
      required: ['facebookToken']
    }
  })
  async linkFacebook(@CurrentUser() user: User, @Body() { facebookToken }: { facebookToken: string }) {
    // TODO: Implement linking existing account with Facebook
    return {
      success: true,
      message: 'Facebook account linked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('unlink-google')
  @ApiOperation({
    summary: 'Unlink Google account',
    description: 'Removes the link between the current user account and their Google account',
  })
  async unlinkGoogle(@CurrentUser() user: User) {
    // TODO: Implement unlinking Google account
    return {
      success: true,
      message: 'Google account unlinked successfully',
      timestamp: new Date().toISOString(),
    };
  }

  @Post('unlink-facebook')
  @ApiOperation({
    summary: 'Unlink Facebook account',
    description: 'Removes the link between the current user account and their Facebook account',
  })
  async unlinkFacebook(@CurrentUser() user: User) {
    // TODO: Implement unlinking Facebook account
    return {
      success: true,
      message: 'Facebook account unlinked successfully',
      timestamp: new Date().toISOString(),
    };
  }
}
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
  UnauthorizedException,
  Inject,
  HttpException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { UserService } from '../user/user.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

import { Public } from './decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { LocalAuthGuard } from './guards/local-auth.guard';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import { FacebookAuthGuard } from './guards/facebook-auth.guard';
import { GoogleLinkAuthGuard } from './guards/google-link-auth.guard';
import { FacebookLinkAuthGuard } from './guards/facebook-link-auth.guard';

import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RequestPasswordResetDto, ResetPasswordDto, ChangePasswordDto } from 'src/user/dto/reset-password.dto';

import { User } from 'src/user/entities/user.entity';

import { ApiOperation, ApiBody, ApiQuery, ApiParam } from '@nestjs/swagger';

@Controller('auth')
export class AuthController {

  private readonly logger = new Logger(AuthController.name);
  constructor(
    private readonly authService: AuthService,
    private readonly userService: UserService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

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

    this.logger.log(`register ${registerDto}`, registerDto);
    console.log(registerDto);
    

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
  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Change password',
    description: 'Change the user\'s password using the current password and new password',
  })
  @ApiBody({
    type: ChangePasswordDto,
    description: 'Change password data including current password and new password',
    required: true,
    examples: {
      example1: {
        summary: 'Change password',
        value: {
          currentPassword: 'OldPassword123!',
          newPassword: 'NewStrongPassword123!',
          confirmPassword: 'NewStrongPassword123!',
        },
      },
    },
  })
  async changePassword(@Body() dto: ChangePasswordDto, @CurrentUser() user: User) {
    await this.authService.changePassword(user.id, dto);
    return {
      success: true,
      message: 'Password changed successfully',
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
  @UseGuards(JwtAuthGuard)
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

  @Post('google/mobile-token')
  @Public()
  @ApiOperation({
    summary: 'Exchange Google OAuth code for tokens (Mobile)',
    description: 'Exchanges authorization code from mobile app for JWT tokens',
  })
  async googleMobileTokenExchange(
    @Body() body: { 
      code: string; 
      redirectUri: string; 
      platform: 'ios' | 'android' 
    }
  ) {
    this.logger.log(`google/mobile-token exchange for ${body.platform}`);
    
    try {
      // Vérifier le code avec la bonne configuration selon la plateforme
      const googleUser = await this.authService.verifyGoogleCodeMobile(
        body.code,
        body.redirectUri,
        body.platform
      );
      
      // Utiliser la même logique de login que pour le web
      const result = await this.authService.googleLogin(googleUser);
      
      // Retourner les tokens en JSON pour l'app mobile
      return {
        success: true,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user
      };
      
    } catch (error) {
      this.logger.error(`Mobile token exchange failed: ${error.message}`, error.stack);
      
      // Retourner une erreur claire
      throw new HttpException(
        {
          statusCode: HttpStatus.BAD_REQUEST,
          message: error.response?.data?.error_description || error.message || 'Authentication failed',
          error: 'Bad Request'
        },
        HttpStatus.BAD_REQUEST
      );
    }
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
      const user = req.user;
      
      // Check if this is a linking request (from the strategy)
      if (user.linkingMode === 'link' && user.linkingToken) {
        // This is a linking flow
        try {
          // Verify the user token
          const payload = this.jwtService.verify(user.linkingToken, { 
            secret: this.configService.get<string>('JWT_SECRET') 
          });
          const currentUser = await this.userService.findByEmail(payload.email);
          
          if (!currentUser) {
            throw new UnauthorizedException('User not found');
          }
          
          // Link the Google account
          await this.authService.linkGoogleProfile(currentUser, user);
          
          // Send success message to parent window (popup)
          res.send(`
            <script>
              window.opener.postMessage({
                type: 'OAUTH_SUCCESS',
                provider: 'google'
              }, window.location.origin);
              window.close();
            </script>
          `);
          return;
        } catch (linkError) {
          // Send error message to parent window (popup)
          res.send(`
            <script>
              window.opener.postMessage({
                type: 'OAUTH_ERROR',
                error: '${linkError.message || 'Failed to link Google account'}'
              }, window.location.origin);
              window.close();
            </script>
          `);
          return;
        }
      }
      
      // Regular login flow
      const result = await this.authService.googleLogin(req.user);
      console.log('Google login successful:', result);

      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const userData = encodeURIComponent(JSON.stringify({
        id: result.user.id,
        email: result.user.email,
        displayName: result.user.displayName,
        avatarUrl: result.user.avatarUrl
      }));
      
      const redirectUrl = `${frontendUrl}/auth/callback?` +
        `token=${result.accessToken}&` +
        `refresh=${result.refreshToken}&` +
        `user=${userData}&` +
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
      const user = req.user;
      
      // Check if this is a linking request (from the strategy)
      if (user.linkingMode === 'link' && user.linkingToken) {
        // This is a linking flow
        try {
          // Verify the user token
          const payload = this.jwtService.verify(user.linkingToken, { 
            secret: this.configService.get<string>('JWT_SECRET') 
          });
          const currentUser = await this.userService.findByEmail(payload.email);
          
          if (!currentUser) {
            throw new UnauthorizedException('User not found');
          }
          
          // Link the Facebook account
          await this.authService.linkFacebookProfile(currentUser, user);
          
          // Send success message to parent window (popup)
          res.send(`
            <script>
              window.opener.postMessage({
                type: 'OAUTH_SUCCESS',
                provider: 'facebook'
              }, window.location.origin);
              window.close();
            </script>
          `);
          return;
        } catch (linkError) {
          // Send error message to parent window (popup)
          res.send(`
            <script>
              window.opener.postMessage({
                type: 'OAUTH_ERROR',
                error: '${linkError.message || 'Failed to link Facebook account'}'
              }, window.location.origin);
              window.close();
            </script>
          `);
          return;
        }
      }
      
      // Regular login flow
      const result = await this.authService.facebookLogin(req.user);
      
      // Redirect to frontend with tokens and minimal user data
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5050';
      const userData = encodeURIComponent(JSON.stringify({
        id: result.user.id,
        email: result.user.email,
        displayName: result.user.displayName,
        avatarUrl: result.user.avatarUrl
      }));
      
      const redirectUrl = `${frontendUrl}/auth/callback?` +
        `token=${result.accessToken}&` +
        `refresh=${result.refreshToken}&` +
        `user=${userData}&` +
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
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Get current user profile',
    description: 'Returns the profile information of the currently authenticated user',
  })
  async getProfile(@CurrentUser() user: User) {
    if (!user) {
      this.logger.warn('getProfile called but user is undefined/null');
      throw new UnauthorizedException('User not found');
    }
    
    // Transform user data to include connectedAccounts
    const userWithConnectedAccounts = {
      ...user,
      connectedAccounts: {
        google: !!user.googleId,
        facebook: !!user.facebookId,
      }
    };
    
    return {
      success: true,
      data: userWithConnectedAccounts,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
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

  @Post('unlink-google')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Unlink Google account',
    description: 'Removes the link between the current user account and their Google account',
  })
  async unlinkGoogle(@CurrentUser() user: User) {
    try {
      await this.authService.unlinkGoogleAccount(user);
      return {
        success: true,
        message: 'Google account unlinked successfully',
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      throw new BadRequestException(error.message || 'Failed to unlink Google account');
    }
  }

  @Post('unlink-facebook')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Unlink Facebook account',
    description: 'Removes the link between the current user account and their Facebook account',
  })
  async unlinkFacebook(@CurrentUser() user: User) {
    try {
      await this.authService.unlinkFacebookAccount(user);
      return {
        success: true,
        message: 'Facebook account unlinked successfully',
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      throw new BadRequestException(error.message || 'Failed to unlink Facebook account');
    }
  }

  // Dedicated OAuth linking endpoints
  @Public()
  @Get('google/link')
  @UseGuards(GoogleLinkAuthGuard)
  @ApiOperation({
    summary: 'Google OAuth linking initiation',
    description: 'Initiates Google OAuth flow specifically for account linking',
  })
  async googleLink(@Query('token') token: string, @Req() req: any) {
    // The token will be passed through the OAuth state parameter
    // The guard will handle the OAuth flow initiation
    
  }

  @Public()
  @Get('google/link-callback')
  @UseGuards(GoogleLinkAuthGuard)
  @ApiOperation({
    summary: 'Google OAuth linking callback',
    description: 'Handles the Google OAuth callback for account linking',
  })
  async googleLinkCallback(@Req() req: Request & { user: any }, @Res() res: Response) {
    
    try {
      const user = req.user;
      
      
      if (!user.linkingToken) {
        
        throw new UnauthorizedException('Missing authentication token for linking');
      }
      
      // Verify the user token
      
      const payload = this.jwtService.verify(user.linkingToken, { 
        secret: this.configService.get<string>('JWT_SECRET') 
      });
      
      const currentUser = await this.userService.findByEmail(payload.email);
      
      if (!currentUser) {
        
        throw new UnauthorizedException('User not found');
      }
      
      // Link the Google account
      
      await this.authService.linkGoogleProfile(currentUser, user);
      
      
      
      // Send success message to parent window (popup)
      res.send(`
        <script>
          window.opener.postMessage({
            type: 'OAUTH_SUCCESS',
            provider: 'google'
          }, '*');
          setTimeout(() => window.close(), 500);
        </script>
      `);
    } catch (error) {
      
      // Send error message to parent window (popup)
      res.send(`
        <script>
          window.opener.postMessage({
            type: 'OAUTH_ERROR',
            error: '${error.message || 'Failed to link Google account'}'
          }, '*');
          setTimeout(() => window.close(), 500);
        </script>
      `);
    }
  }

  @Public()
  @Get('facebook/link')
  @UseGuards(FacebookLinkAuthGuard)
  @ApiOperation({
    summary: 'Facebook OAuth linking initiation',
    description: 'Initiates Facebook OAuth flow specifically for account linking',
  })
  async facebookLink(@Query('token') token: string, @Req() req: any) {
    // The token will be passed through the OAuth state parameter
    // The guard will handle the OAuth flow initiation
    
  }

  @Public()
  @Get('facebook/link-callback')
  @UseGuards(FacebookLinkAuthGuard)
  @ApiOperation({
    summary: 'Facebook OAuth linking callback',
    description: 'Handles the Facebook OAuth callback for account linking',
  })
  async facebookLinkCallback(@Req() req: Request & { user: any }, @Res() res: Response) {
    
    try {
      const user = req.user;
      
      
      if (!user.linkingToken) {
        
        throw new UnauthorizedException('Missing authentication token for linking');
      }
      
      // Verify the user token
      
      const payload = this.jwtService.verify(user.linkingToken, { 
        secret: this.configService.get<string>('JWT_SECRET') 
      });
      
      const currentUser = await this.userService.findByEmail(payload.email);
      
      if (!currentUser) {
        
        throw new UnauthorizedException('User not found');
      }
      
      // Link the Facebook account
      
      await this.authService.linkFacebookProfile(currentUser, user);
      
      
      
      // Send success message to parent window (popup)
      res.send(`
        <script>
          window.opener.postMessage({
            type: 'OAUTH_SUCCESS',
            provider: 'facebook'
          }, '*');
          setTimeout(() => window.close(), 500);
        </script>
      `);
    } catch (error) {
      
      // Send error message to parent window (popup)
      res.send(`
        <script>
          window.opener.postMessage({
            type: 'OAUTH_ERROR',
            error: '${error.message || 'Failed to link Facebook account'}'
          }, '*');
          setTimeout(() => window.close(), 500);
        </script>
      `);
    }
  }
}
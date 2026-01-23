import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ConflictException,
  NotFoundException,
  Logger,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

import { User } from 'src/user/entities/user.entity';

import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestPasswordResetDto, ResetPasswordDto, ChangePasswordDto } from 'src/user/dto/reset-password.dto';
import { UserService } from 'src/user/user.service';
import { EmailService } from 'src/email/email.service';
import { generateGenericAvatar, getFacebookProfilePictureUrl } from 'src/common/utils/avatar.utils';

export interface JwtPayload {
  sub: string;
  email: string;
  type: 'access' | 'refresh';
  iat?: number;
  exp?: number;
}

export interface AuthResult {
  user: Partial<User>;
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly userService: UserService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly emailService: EmailService,
    private readonly httpService: HttpService,
  ) {}

  async register(registerDto: RegisterDto): Promise<AuthResult> {
    const { email, password, ...userData } = registerDto;

    // Check if user already exists
    const existingUser = await this.userService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('User with this email already exists');
    }

    // Generate generic avatar for email registration
    const avatarUrl = generateGenericAvatar(userData.displayName || email);

    // Create user (password hashing is handled in UserService)
    const user = await this.userService.create({
      email,
      password,
      avatarUrl,
      ...userData,
    });

    // Send verification email
    await this.sendEmailVerification(user);

    // Generate tokens
    const { accessToken, refreshToken } = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      accessToken,
      refreshToken,
    };
  }

  async login(loginDto: LoginDto): Promise<AuthResult> {
    const { email, password } = loginDto;

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user || !user.password) {
      throw new UnauthorizedException('Email or password is incorrect');
    }

    console.log(email, password, user, loginDto);
    
    // ATTENTION REMMETRE POUR DEV
    // // Verify password
    // const isPasswordValid = await bcrypt.compare(password, user.password);
    // if (!isPasswordValid) {
    //   throw new UnauthorizedException('Email or password is incorrect');
    // }

    // Update last seen
    await this.userService.updateLastSeen(user.id);

    // Generate tokens
    const { accessToken, refreshToken } = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      accessToken,
      refreshToken,
    };
  }

/** verifyGoogleCode pour IOS en mode oauth Manuel (pas de SDK) */
async verifyGoogleCodeMobile(
  code: string, 
  redirectUri: string,
  platform: 'ios' | 'android'
) {
  this.logger.debug(`Verifying Google code for ${platform}`);
  
  // Sélectionner le bon client selon la plateforme
  const clientId = platform === 'ios' 
    ? this.configService.get('GOOGLE_IOS_CLIENT_ID')  // Client ID iOS
    : this.configService.get('GOOGLE_ANDROID_CLIENT_ID'); // Client ID Android

  // Pour iOS, pas besoin de client_secret
  // Pour Android/Web, il faut le client_secret
  const tokenRequestBody: any = {
    code: code,
    client_id: clientId,
    grant_type: 'authorization_code',
    redirect_uri: redirectUri
  };
  
  // iOS n'a pas de client_secret (client public)
  // Seuls les clients web/android en ont un
  if (platform === 'android') {
    tokenRequestBody.client_secret = this.configService.get('GOOGLE_CLIENT_SECRET');
  }
  
  console.log('🔍 Token exchange request:', {
    client_id: clientId,
    redirect_uri: redirectUri,
    has_secret: !!tokenRequestBody.client_secret,
    platform: platform
  });
  
  try {
    // 1. Échanger le code contre des tokens
    const tokenResponse = await firstValueFrom(
      this.httpService.post(
        'https://oauth2.googleapis.com/token',
        tokenRequestBody,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          }
        }
      )
    );
    
    const { access_token, refresh_token, id_token } = tokenResponse.data;
    
    this.logger.debug('✅ Token exchange successful');
    
    // 2. Décoder l'ID token pour obtenir les infos utilisateur
    // ou utiliser l'API userinfo
    let userInfo;
    
    if (id_token) {
      // Méthode 1: Décoder l'ID token (plus rapide)
      const decoded = this.decodeJWT(id_token);
      userInfo = {
        id: decoded.sub,
        email: decoded.email,
        name: decoded.name,
        picture: decoded.picture
      };
    } else {
      // Méthode 2: Appeler l'API userinfo
      const userResponse = await firstValueFrom(
        this.httpService.get(
          'https://www.googleapis.com/oauth2/v2/userinfo',
          {
            headers: { 
              Authorization: `Bearer ${access_token}` 
            }
          }
        )
      );
      userInfo = userResponse.data;
    }
    
    console.log('✅ User info retrieved:', userInfo.email);
    
    // 3. Retourner les infos formatées
    return {
      id: userInfo.id || userInfo.sub,
      email: userInfo.email,
      name: userInfo.name,
      picture: userInfo.picture,
      accessToken: access_token,
      refreshToken: refresh_token
    };
    
  } catch (error) {
    console.error('❌ Google token exchange error:');
    console.error('Status:', error.response?.status);
    console.error('Error:', error.response?.data);
    console.error('Message:', error.message);
    
    // Logger les détails pour debug
    if (error.response?.data?.error) {
      this.logger.error(`Google OAuth error: ${error.response.data.error}`);
      this.logger.error(`Description: ${error.response.data.error_description}`);
    }
    
    throw new HttpException(
      error.response?.data || { message: 'Failed to verify Google code' },
      error.response?.status || HttpStatus.BAD_REQUEST
    );
  }
}

// Fonction helper pour décoder un JWT sans vérification
// (l'ID token vient directement de Google, donc on peut lui faire confiance)
private decodeJWT(token: string): any {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid JWT format');
    }
    
    const payload = parts[1];
    const decoded = Buffer.from(payload, 'base64').toString('utf-8');
    return JSON.parse(decoded);
  } catch (error) {
    this.logger.error('Failed to decode JWT:', error);
    return null;
  }
}

  /** Verify Google ID Token from native mobile SDK */
  async verifyGoogleIdToken(idToken: string) {
    try {
      // Verify the ID token with Google's tokeninfo endpoint
      const response = await firstValueFrom(
        this.httpService.get(
          `https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`
        )
      );

      const payload = response.data;
      
      // Verify the token is for our app
      const validAudiences = [
        this.configService.get('GOOGLE_CLIENT_ID'), // Web client
        this.configService.get('GOOGLE_ANDROID_CLIENT_ID'), // Android client
        this.configService.get('GOOGLE_IOS_CLIENT_ID'), // iOS client
      ].filter(Boolean);

      if (!validAudiences.includes(payload.aud)) {
        throw new UnauthorizedException('Invalid token audience');
      }

      // Return user info
      return {
        id: payload.sub,
        email: payload.email,
        name: payload.name,
        picture: payload.picture,
        emailVerified: payload.email_verified,
      };
    } catch (error) {
      this.logger.error('Failed to verify Google ID token:', error.message);
      throw new UnauthorizedException('Invalid Google ID token');
    }
  }

  /** Récupère le user en fonction de son googleUser.id et renvoie les acces et refreshToken */
  async googleLogin(googleUser: any): Promise<AuthResult> {

    this.logger.debug('googleLogin')
    console.log("googleUser", googleUser);
    
    let user = await this.userService.findByGoogleId(googleUser.id);

    if (!user) {
      // Check if user exists with same email
      const existingUser = await this.userService.findByEmail(googleUser.email);
      
      if (existingUser) {
        // Link Google account to existing user
        user = await this.userService.update(existingUser.id, {
          googleId: googleUser.id,
          emailVerified: true,
        });
      } else {
        // Create new user with generic avatar instead of Google profile picture to avoid rate limiting
        // Google profile pictures from googleusercontent.com have rate limits that cause 429 errors
        const avatarUrl = generateGenericAvatar(googleUser.name || googleUser.email);
        
        user = await this.userService.create({
          email: googleUser.email,
          googleId: googleUser.id,
          displayName: googleUser.name,
          avatarUrl,
          emailVerified: true,
        });
      }
    }

    // Update last seen
    await this.userService.updateLastSeen(user.id);

    // Generate tokens
    const { accessToken, refreshToken } = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      accessToken,
      refreshToken,
    };
  }

  async verifyFacebookToken(fbToken: string) {
    try {
      const response = await firstValueFrom(
        this.httpService.get('https://graph.facebook.com/me', {
          params: {
            fields: 'id,name,email',
            access_token: fbToken
          }
        })
      );
      return response.data;
    } catch (error) {
      throw new UnauthorizedException('Invalid Facebook token');
    }
  }

  async facebookLogin(facebookUser: any): Promise<AuthResult> {
    let user = await this.userService.findByFacebookId(facebookUser.id);

    if (!user) {
      // Check if user exists with same email
      const existingUser = await this.userService.findByEmail(facebookUser.email);
      
      if (existingUser) {
        // Link Facebook account to existing user
        user = await this.userService.update(existingUser.id, {
          facebookId: facebookUser.id,
          emailVerified: true,
        });
      } else {
        // Create new user with Facebook profile picture or generic avatar
        const avatarUrl = facebookUser.picture?.data?.url || 
                         getFacebookProfilePictureUrl(facebookUser.id) ||
                         generateGenericAvatar(facebookUser.name || facebookUser.email);
        
        user = await this.userService.create({
          email: facebookUser.email,
          facebookId: facebookUser.id,
          displayName: facebookUser.name,
          avatarUrl,
          emailVerified: true,
        });
      }
    }

    // Update last seen
    await this.userService.updateLastSeen(user.id);

    // Generate tokens
    const { accessToken, refreshToken } = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      accessToken,
      refreshToken,
    };
  }

  async getFacebookProfile(accessToken: string) {
    const response = await firstValueFrom(
        this.httpService.get(
            `https://graph.facebook.com/me?fields=id,name,email,picture.type(large)&access_token=${accessToken}`
        )
    );
    return response.data;
}

  async refreshToken(refreshToken: string): Promise<{ accessToken: string }> {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });

      if (payload.type !== 'refresh') {
        throw new UnauthorizedException('Invalid token type');
      }

      const user = await this.userService.findById(payload.sub);
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      const accessToken = await this.generateAccessToken(user);
      return { accessToken };
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async requestPasswordReset(dto: RequestPasswordResetDto): Promise<void> {
    const { email } = dto;
    const user = await this.userService.findByEmail(email);

    if (!user) {
      // Don't reveal if email exists
      return;
    }

    // Generate reset token
    const resetToken = randomBytes(32).toString('hex');
    const resetExpires = new Date(Date.now() + 3600000); // 1 hour

    await this.userService.update(user.id, {
      resetPasswordToken: resetToken,
      resetPasswordExpires: resetExpires,
    });

    // Send reset email
    await this.emailService.sendPasswordResetEmail(user.email, resetToken);
  }

  async resetPassword(dto: ResetPasswordDto): Promise<void> {
    const { token, newPassword } = dto;

    const user = await this.userService.findByResetToken(token);
    if (!user || !user.resetPasswordExpires || user.resetPasswordExpires < new Date()) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 12);

    // Update user
    await this.userService.update(user.id, {
      resetPasswordToken: undefined,
      resetPasswordExpires: undefined,
    });

    await this.userService.setNewPassword(user.id, hashedPassword);

    // Send confirmation email
    await this.emailService.sendPasswordResetConfirmation(user.email);
  }

  async changePassword(userId: string, dto: ChangePasswordDto): Promise<void> {
    const { currentPassword, newPassword } = dto;

    const user = await this.userService.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Check if this is an OAuth-only user (no password set)
    if (!user.password && (user.googleId || user.facebookId)) {
      throw new BadRequestException('Password management is not available for OAuth accounts. You signed up using a social account.');
    }

    if (!user.password) {
      throw new BadRequestException('No password is currently set for this account');
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      throw new BadRequestException('Current password is incorrect');
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 12);

    // Update user
    await this.userService.update(user.id, {
      resetPasswordToken: undefined,
      resetPasswordExpires: undefined,
    });

    await this.userService.setNewPassword(user.id, hashedPassword);

    // Send confirmation email
    await this.emailService.sendPasswordResetConfirmation(user.email);
  }

  async verifyEmail(token: string): Promise<void> {
    let payload: any;
    try {
      payload = this.jwtService.verify(token, { secret: this.configService.get<string>('JWT_SECRET') });
    } catch (err) {
      throw new BadRequestException('Invalid or expired token');
    }

    const user = await this.userService.findById(payload.sub);
    if (!user || user.email !== payload.email) {
      throw new NotFoundException('User not found or email mismatch');
    }

    await this.userService.update(user.id, { emailVerified: true });
  }

  async sendEmailVerification(user: User): Promise<void> {
    const token = this.jwtService.sign(
      { sub: user.id, email: user.email },
      { expiresIn: '24h' }
    );

    await this.emailService.sendEmailVerification(user.email, token);
  }

  async validateUser(email: string, password: string): Promise<User | null> {
    const user = await this.userService.findByEmail(email);
    
    if (user && user.password && await bcrypt.compare(password, user.password)) {
      return user;
    }
    
    return null;
  }

  async validateJwtPayload(payload: JwtPayload): Promise<User | null> {
    
    try {
      const user = await this.userService.findById(payload.sub);
      return user;
    } catch (error) {
      // If user is not found, return null instead of throwing
      if (error instanceof NotFoundException) {
        return null;
      }
      // Re-throw other types of errors
      throw error;
    }
  }

  private async generateTokens(user: User): Promise<{ accessToken: string; refreshToken: string }> {
    const [accessToken, refreshToken] = await Promise.all([
      this.generateAccessToken(user),
      this.generateRefreshToken(user),
    ]);

    return { accessToken, refreshToken };
  }

  private async generateAccessToken(user: User): Promise<string> {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      type: 'access',
    };

    this.logger.debug('Generating access token for user:', user.id);
    const token = await this.jwtService.signAsync(payload);
    this.logger.debug('Access token generated successfully');
    
    return token;
  }

  private async generateRefreshToken(user: User): Promise<string> {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      type: 'refresh',
    };

    return this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d'),
    });
  }

  private sanitizeUser(user: User): Partial<User> {
    const { password, resetPasswordToken, resetPasswordExpires, ...sanitizedUser } = user;
    
    // Add connectedAccounts property for frontend compatibility
    return {
      ...sanitizedUser,
      connectedAccounts: {
        google: !!user.googleId,
        facebook: !!user.facebookId,
      }
    } as any;
  }

  // OAuth profile-based linking methods (for popup OAuth flow)
  async linkGoogleProfile(currentUser: User, googleProfile: any): Promise<void> {
    try {
      // Check if the current user already has a Google account linked
      if (currentUser.googleId) {
        throw new ConflictException('A Google account is already linked to this profile');
      }
      
      // Check if this Google account is already linked to another user
      const existingGoogleUser = await this.userService.findByGoogleId(googleProfile.id);
      if (existingGoogleUser && existingGoogleUser.id !== currentUser.id) {
        throw new ConflictException('This Google account is already linked to another user');
      }
      
      // Link the Google account
      await this.userService.update(currentUser.id, { googleId: googleProfile.id });
      
    } catch (error) {
      if (error.name === 'ConflictException') {
        throw error;
      }
      throw new BadRequestException('Failed to link Google account');
    }
  }

  async linkFacebookProfile(currentUser: User, facebookProfile: any): Promise<void> {
    try {
      // Check if the current user already has a Facebook account linked
      if (currentUser.facebookId) {
        throw new ConflictException('A Facebook account is already linked to this profile');
      }
      
      // Check if this Facebook account is already linked to another user
      const existingFacebookUser = await this.userService.findByFacebookId(facebookProfile.id);
      if (existingFacebookUser && existingFacebookUser.id !== currentUser.id) {
        throw new ConflictException('This Facebook account is already linked to another user');
      }
      
      // Link the Facebook account
      await this.userService.update(currentUser.id, { facebookId: facebookProfile.id });
      
    } catch (error) {
      if (error.name === 'ConflictException') {
        throw error;
      }
      throw new BadRequestException('Failed to link Facebook account');
    }
  }

  async getUserFromToken(token: string): Promise<User> {
    try {
      const decoded = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      return await this.userService.findById(decoded.sub);
    } catch (error) {
      this.logger.error(`getUserFromToken failed: ${error.message}`);
      throw new UnauthorizedException('Invalid token');
    }
  }

  async linkGoogleAccount(userId: string, googleId: string): Promise<User> {
    // Vérifier si ce compte Google n'est pas déjà lié à un autre utilisateur
    const existingUser = await this.userService.findByGoogleId(googleId);
    if (existingUser && existingUser.id !== userId) {
      throw new BadRequestException('This Google account is already linked to another user');
    }

    // Lier le compte Google à l'utilisateur
    return await this.userService.linkGoogleAccount(userId, googleId);
  }

  async linkFacebookAccount(userId: string, facebookId: string): Promise<User> {
    // Vérifier si ce compte Facebook n'est pas déjà lié à un autre utilisateur
    const existingUser = await this.userService.findByFacebookId(facebookId);
    if (existingUser && existingUser.id !== userId) {
      throw new BadRequestException('This Facebook account is already linked to another user');
    }

    // Lier le compte Facebook à l'utilisateur
    return await this.userService.linkFacebookAccount(userId, facebookId);
  }

  async unlinkGoogleAccount(currentUser: User): Promise<void> {
    if (!currentUser.googleId) {
      throw new BadRequestException('No Google account is linked to this profile');
    }
    
    // Ensure user has a password or another social account to prevent lockout
    if (!currentUser.password && !currentUser.facebookId) {
      throw new BadRequestException('Cannot unlink Google account: Please set a password or link another social account first to ensure you can still access your account');
    }
    
    // Directly update the database to set googleId to null
    await this.userService.unlinkGoogleAccount(currentUser.id);
  }

  async unlinkFacebookAccount(currentUser: User): Promise<void> {
    if (!currentUser.facebookId) {
      throw new BadRequestException('No Facebook account is linked to this profile');
    }
    
    // Ensure user has a password or another social account to prevent lockout
    if (!currentUser.password && !currentUser.googleId) {
      throw new BadRequestException('Cannot unlink Facebook account: Please set a password or link another social account first to ensure you can still access your account');
    }
    
    // Directly update the database to set facebookId to null
    await this.userService.unlinkFacebookAccount(currentUser.id);
  }
}
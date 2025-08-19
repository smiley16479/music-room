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
import { RequestPasswordResetDto, ResetPasswordDto } from 'src/user/dto/reset-password.dto';
import { UserService } from 'src/user/user.service';
import { EmailService } from 'src/email/email.service';

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

    // Create user (password hashing is handled in UserService)
    const user = await this.userService.create({
      email,
      password,
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
        // Create new user
        user = await this.userService.create({
          email: googleUser.email,
          googleId: googleUser.id,
          displayName: googleUser.name,
          avatarUrl: googleUser.picture,
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

async verifyGoogleIdToken(idToken: string) {
    const response = await firstValueFrom(
        this.httpService.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`)
    );
    return response.data; // Contient les infos user
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
        // Create new user
        user = await this.userService.create({
          email: facebookUser.email,
          facebookId: facebookUser.id,
          displayName: facebookUser.name,
          avatarUrl: facebookUser.picture?.data?.url,
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
    return this.userService.findById(payload.sub);
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

    return this.jwtService.signAsync(payload);
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
    return sanitizedUser;
  }
}
import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ConflictException,
  NotFoundException,
  Logger,
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

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Email or password is incorrect');
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

  /** verifyGoogleCode pour IOS en mode oauth Manuel (pas de SDK) */
  async verifyGoogleCode(code: string) {
    // 1. Échanger le code contre un access token Google

    this.logger.debug('verifyGoogleCode')

    console.log('🔍 Debug Google token exchange:');
    console.log('Client ID:', this.configService.get('GOOGLE_WEB_CLIENT_ID'));
    console.log('Client Secret exists:', this.configService.get('GOOGLE_CLIENT_SECRET'));
    console.log('Code:', code);
    console.log('Redirect URI:', 'com.googleusercontent.apps.734605703797-duvg1eiupfeva2njit9chbpq0bvmstke://');

    try {
      const tokenResponse = await firstValueFrom(
          this.httpService.post('https://oauth2.googleapis.com/token', {
              client_id: this.configService.get('GOOGLE_WEB_CLIENT_ID'),
              client_secret: this.configService.get('GOOGLE_CLIENT_SECRET'),
              code: code,
              grant_type: 'authorization_code',
              redirect_uri: 'urn:ietf:wg:oauth:2.0:oob' // 'http://localhost' // 'com.googleusercontent.apps.734605703797-duvg1eiupfeva2njit9chbpq0bvmstke://'
          })
      );


      const { access_token } = tokenResponse.data;
      this.logger.debug('verifyGoogleCode1')

      // 2. Utiliser l'access token pour récupérer les infos utilisateur
      const userResponse = await firstValueFrom(
          this.httpService.get('https://www.googleapis.com/oauth2/v2/userinfo', {
              headers: { Authorization: `Bearer ${access_token}` }
          })
      );

      console.log("verifyGoogleCode userResponse.data:", userResponse.data);
      // 3. Formater comme votre GoogleStrategy le fait
      const googleUser = userResponse.data;
      return {
          id: googleUser.id,
          email: googleUser.email,
          name: googleUser.name,
          picture: googleUser.picture,
          accessToken: access_token
      };
    } catch (error) {
        console.error('❌ Google token exchange error:');
        console.error('Status:', error.response?.status);
        console.error('Data:', error.response?.data);
        console.error('Message:', error.message);
        throw error;
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
    return sanitizedUser;
  }
}
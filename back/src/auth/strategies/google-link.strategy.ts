import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback } from 'passport-google-oauth20';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class GoogleLinkStrategy extends PassportStrategy(Strategy, 'google-link') {
  constructor(configService: ConfigService) {
    const clientID = configService.get<string>('GOOGLE_CLIENT_ID');
    const clientSecret = configService.get<string>('GOOGLE_CLIENT_SECRET');
    const callbackURL = configService.get<string>('GOOGLE_LINK_CALLBACK_URL');
    
    console.log('Google Link Strategy - Callback URL:', callbackURL);

    if (!clientID || !clientSecret || !callbackURL)
      throw new Error('Missing required Google OAuth environment variables');

    super({
      clientID: clientID,
      clientSecret: clientSecret,
      callbackURL: callbackURL,
      scope: ['email', 'profile'],
      passReqToCallback: true,
    });
  }

  async validate(
    req: any,
    accessToken: string,
    refreshToken: string,
    profile: any,
    done: VerifyCallback,
  ): Promise<any> {
    console.log('Google link strategy validate reached');
    console.log('Profile:', profile);
    console.log('Request query:', req.query);
    
    const { id, name, emails, photos } = profile;
    
    // Get the token from the state parameter (passed through OAuth flow)
    const linkingToken = req.query.state;
    
    const user = {
      id,
      email: emails[0].value,
      name: `${name.givenName} ${name.familyName}`,
      picture: photos[0].value,
      accessToken,
      // This strategy is specifically for linking
      isLinking: true,
      linkingToken: linkingToken,
    };
    
    console.log('Google link user object:', user);
    done(null, user);
  }
}

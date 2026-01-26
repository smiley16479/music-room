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
    
    // Get the token and redirect_uri from the state parameter (passed through OAuth flow)
    let linkingToken: string | undefined;
    let redirectUri: string | undefined;
    
    try {
      const stateData = JSON.parse(req.query.state || '{}');
      linkingToken = stateData.token;
      redirectUri = stateData.redirect_uri;
    } catch (e) {
      // State might be just a plain token string (backwards compatibility)
      linkingToken = req.query.state;
    }
    
    const user = {
      id,
      email: emails[0].value,
      name: `${name.givenName} ${name.familyName}`,
      picture: photos[0].value,
      accessToken,
      // This strategy is specifically for linking
      linkingMode: 'link',
      linkingToken: linkingToken,
      redirectUri: redirectUri,
    };
    
    console.log('Google link user object:', user);
    done(null, user);
  }
}

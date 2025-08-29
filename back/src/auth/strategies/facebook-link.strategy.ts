import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, Profile } from 'passport-facebook';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class FacebookLinkStrategy extends PassportStrategy(Strategy, 'facebook-link') {
  constructor(private configService: ConfigService) {
    const clientID = configService.get<string>('FACEBOOK_APP_ID');
    const clientSecret = configService.get<string>('FACEBOOK_APP_SECRET');
    const callbackURL = configService.get<string>('FACEBOOK_LINK_CALLBACK_URL');
    
    if (!clientID || !clientSecret || !callbackURL) {
      throw new Error('Missing Facebook OAuth configuration');
    }
    
    super({
      clientID,
      clientSecret,
      callbackURL,
      scope: 'email',
      profileFields: ['emails', 'name', 'picture.type(large)'],
      passReqToCallback: true,
    });
  }

  async validate(
    req: any,
    accessToken: string,
    refreshToken: string,
    profile: Profile,
    done: (err: any, user: any, info?: any) => void,
  ): Promise<any> {
    console.log('Facebook link strategy validate reached');
    console.log('Profile:', profile);
    console.log('Request query:', req.query);
    
    const { id, name, emails, photos } = profile;
    
    // Get the token from the state parameter (passed through OAuth flow)
    const linkingToken = req.query.state;
    
    const user = {
      id,
      email: emails?.[0]?.value,
      name: `${name?.givenName} ${name?.familyName}`,
      picture: photos?.[0],
      accessToken,
      // This strategy is specifically for linking
      linkingMode: 'link',
      linkingToken: linkingToken,
    };
    
    console.log('Facebook link user object:', user);
    done(null, user);
  }
}

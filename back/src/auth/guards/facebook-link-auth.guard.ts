import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class FacebookLinkAuthGuard extends AuthGuard('facebook-link') {
  getAuthenticateOptions(context: any) {
    const request = context.switchToHttp().getRequest();
    const token = request.query.state; // JWT token for user authentication
    const redirectUri = request.query.redirect_uri;
    
    // Pass both token and redirect_uri through state as JSON
    const stateData: any = {};
    if (token) stateData.token = token;
    if (redirectUri) stateData.redirect_uri = redirectUri;
    
    if (Object.keys(stateData).length > 0) {
      return {
        state: JSON.stringify(stateData),
      };
    }
    
    return {};
  }
}

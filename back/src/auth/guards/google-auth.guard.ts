// src/auth/guards/google-auth.guard.ts
import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class GoogleAuthGuard extends AuthGuard('google') {
  getAuthenticateOptions(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const redirectUri = request.query.redirect_uri;
    
    if (redirectUri) {
      // Pass redirect_uri in state parameter
      return {
        state: JSON.stringify({ redirect_uri: redirectUri }),
      };
    }
    
    return {};
  }
}
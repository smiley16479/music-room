import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class GoogleLinkAuthGuard extends AuthGuard('google-link') {
  getAuthenticateOptions(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const token = request.query.token;
    
    if (token) {
      return {
        state: token, // Pass the token through the state parameter
      };
    }
    
    return {};
  }
}

import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class AuthResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map(data => {
        // Remove sensitive data from responses
        if (data?.data?.user) {
          const { password, resetPasswordToken, resetPasswordExpires, ...sanitizedUser } = data.data.user;
          data.data.user = sanitizedUser;
        }
        
        return data;
      }),
    );
  }
}
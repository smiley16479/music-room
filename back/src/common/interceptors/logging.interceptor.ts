import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Request, Response } from 'express';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();
    const { method, url, body, query, params } = request;
    const userAgent = request.get('user-agent') || '';
    const ip = request.ip;
    const now = Date.now();

    // Safe checks for body, query, params
    const safeBody = body || {};
    const safeQuery = query || {};
    const safeParams = params || {};

    // Log incoming request
    this.logger.log(`
╔════════════════════════════════════════════════════════════════
║ 📥 INCOMING REQUEST
╠════════════════════════════════════════════════════════════════
║ Method: ${method}
║ URL: ${url}
║ IP: ${ip}
║ User-Agent: ${userAgent}
╠────────────────────────────────────────────────────────────────
║ Query Params: ${Object.keys(safeQuery).length > 0 ? JSON.stringify(safeQuery, null, 2) : 'None'}
║ Route Params: ${Object.keys(safeParams).length > 0 ? JSON.stringify(safeParams, null, 2) : 'None'}
║ Body: ${Object.keys(safeBody).length > 0 ? JSON.stringify(safeBody, null, 2) : 'None'}
╚════════════════════════════════════════════════════════════════
    `);

    return next.handle().pipe(
      tap({
        next: (data) => {
          const responseTime = Date.now() - now;
          this.logger.log(`
╔════════════════════════════════════════════════════════════════
║ 📤 RESPONSE
╠════════════════════════════════════════════════════════════════
║ Method: ${method}
║ URL: ${url}
║ Status: ${response.statusCode}
║ Response Time: ${responseTime}ms
╚════════════════════════════════════════════════════════════════
          `);
        },
        error: (error) => {
          const responseTime = Date.now() - now;
          this.logger.error(`
╔════════════════════════════════════════════════════════════════
║ ❌ ERROR RESPONSE
╠════════════════════════════════════════════════════════════════
║ Method: ${method}
║ URL: ${url}
║ Status: ${response.statusCode}
║ Response Time: ${responseTime}ms
║ Error: ${error.message}
╚════════════════════════════════════════════════════════════════
          `);
        },
      }),
    );
  }
}

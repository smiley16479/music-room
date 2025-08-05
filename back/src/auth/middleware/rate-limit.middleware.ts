import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { ConfigService } from '@nestjs/config';

interface RateLimitStore {
  [key: string]: {
    count: number;
    resetTime: number;
  };
}

@Injectable()
export class RateLimitMiddleware implements NestMiddleware {
  private store: RateLimitStore = {};
  private readonly maxRequests: number;
  private readonly windowMs: number;

  constructor(private configService: ConfigService) {
    this.maxRequests = this.configService.get<number>('RATE_LIMIT_LIMIT', 100);
    this.windowMs = this.configService.get<number>('RATE_LIMIT_TTL', 60) * 1000;
  }

  use(req: Request, res: Response, next: NextFunction): void {
    const key = this.getKey(req);
    const now = Date.now();
    
    if (!this.store[key] || now > this.store[key].resetTime) {
      this.store[key] = {
        count: 1,
        resetTime: now + this.windowMs,
      };
    } else {
      this.store[key].count++;
    }

    const { count, resetTime } = this.store[key];
    
    res.setHeader('X-RateLimit-Limit', this.maxRequests);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, this.maxRequests - count));
    res.setHeader('X-RateLimit-Reset', new Date(resetTime).toISOString());

    if (count > this.maxRequests) {
      res.status(429).json({
        success: false,
        error: 'Too many requests',
        message: 'Rate limit exceeded. Please try again later.',
        timestamp: new Date().toISOString(),
      });
      return;
    }

    next();
  }

  private getKey(req: Request): string {
    // Use IP address as key, but you could also use user ID for authenticated requests
    const forwarded = req.headers['x-forwarded-for'] as string;
    const ip = forwarded ? forwarded.split(',')[0] : req.connection.remoteAddress;
    return `${ip}:${req.path}`;
  }
}
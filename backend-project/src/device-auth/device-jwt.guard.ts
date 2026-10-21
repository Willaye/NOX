import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { DeviceJwtService } from './device-jwt.service.js';

/**
 * Guards endpoints that are called BY an enrolled device (heartbeat, tracking
 * uploads, unlock events, …). Expects `Authorization: Bearer <device-jwt>`.
 *
 * On success, sets `req.device = { id, ownerId? }` so controllers can trust
 * the deviceId instead of taking it from the body/URL — this closes the
 * current gap where any client can heartbeat any device by guessing its id.
 */
declare module 'express-serve-static-core' {
  interface Request {
    device?: { id: string; ownerId?: string };
  }
}

@Injectable()
export class DeviceJwtGuard implements CanActivate {
  constructor(private readonly deviceJwt: DeviceJwtService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const header = req.headers?.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing device token');
    }
    const token = header.slice('Bearer '.length).trim();
    const payload = this.deviceJwt.verify(token);
    req.device = { id: payload.sub, ownerId: payload.ownerId };
    return true;
  }
}

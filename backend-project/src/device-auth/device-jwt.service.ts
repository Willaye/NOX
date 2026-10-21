import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

/**
 * Payload for device-authenticated JWTs. These are separate from user JWTs:
 *   - user tokens have `sub = userId`, `role`, `email`
 *   - device tokens have `sub = deviceId`, `typ = 'device'`
 *
 * The `typ` claim is the discriminator the guard enforces, so a stolen user
 * token can't be used in place of a device token even though both are signed
 * with the same JWT_SECRET.
 */
export interface DeviceJwtPayload {
  sub: string; // deviceId
  typ: 'device';
  // Optional ownership context so the device can self-identify in logs
  ownerId?: string;
}

@Injectable()
export class DeviceJwtService {
  constructor(private readonly jwt: JwtService) {}

  /**
   * Mint a long-lived device JWT. Devices use this for every API call after
   * enrollment, so the expiry is deliberately long (90 days). The device can
   * re-enroll if the token expires.
   */
  sign(deviceId: string, ownerId?: string): string {
    const payload: DeviceJwtPayload = {
      sub: deviceId,
      typ: 'device',
      ...(ownerId ? { ownerId } : {}),
    };
    return this.jwt.sign(payload, { expiresIn: '3650d' });
  }

  /**
   * Verify + extract. Throws UnauthorizedException on any failure (bad
   * signature, expired, wrong `typ`).
   */
  verify(token: string): DeviceJwtPayload {
    let decoded: DeviceJwtPayload;
    try {
      decoded = this.jwt.verify<DeviceJwtPayload>(token);
    } catch {
      throw new UnauthorizedException('Invalid device token');
    }
    if (decoded.typ !== 'device' || !decoded.sub) {
      throw new UnauthorizedException('Invalid device token');
    }
    return decoded;
  }
}

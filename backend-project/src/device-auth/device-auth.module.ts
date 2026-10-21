import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceJwtService } from './device-jwt.service.js';
import { DeviceJwtGuard } from './device-jwt.guard.js';

/**
 * Device-authentication module. Depends on AuthModule only to reuse the
 * already-configured JwtModule (same signing secret, different `typ` claim).
 */
@Module({
  imports: [AuthModule],
  providers: [DeviceJwtService, DeviceJwtGuard],
  exports: [DeviceJwtService, DeviceJwtGuard],
})
export class DeviceAuthModule {}

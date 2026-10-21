import { Module } from '@nestjs/common';
import { TrackingService } from './tracking.service.js';
import { TrackingController } from './tracking.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceAuthModule } from '../device-auth/device-auth.module.js';
import { GatewayModule } from '../gateway/gateway.module.js';

@Module({
  // AuthModule for admin reads, DeviceAuthModule for device writes,
  // GatewayModule for real-time unlock broadcasts. FcmModule is global.
  imports: [AuthModule, DeviceAuthModule, GatewayModule],
  controllers: [TrackingController],
  providers: [TrackingService],
  exports: [TrackingService],
})
export class TrackingModule {}

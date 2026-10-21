import { Module } from '@nestjs/common';
import { LocationLogService } from './location-log.service.js';
import { LocationLogController } from './location-log.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceAuthModule } from '../device-auth/device-auth.module.js';

@Module({
  imports: [AuthModule, DeviceAuthModule],
  controllers: [LocationLogController],
  providers: [LocationLogService],
  exports: [LocationLogService],
})
export class LocationLogModule {}

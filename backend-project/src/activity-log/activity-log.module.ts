import { Module } from '@nestjs/common';
import { ActivityLogService } from './activity-log.service.js';
import { ActivityLogController } from './activity-log.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceAuthModule } from '../device-auth/device-auth.module.js';

@Module({
  imports: [AuthModule, DeviceAuthModule],
  controllers: [ActivityLogController],
  providers: [ActivityLogService],
  exports: [ActivityLogService],
})
export class ActivityLogModule {}

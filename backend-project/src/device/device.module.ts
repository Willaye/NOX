import { Module } from '@nestjs/common';
import { DeviceService } from './device.service.js';
import { DeviceController } from './device.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceAuthModule } from '../device-auth/device-auth.module.js';

@Module({
  imports: [AuthModule, DeviceAuthModule],
  controllers: [DeviceController],
  providers: [DeviceService],
  exports: [DeviceService],
})
export class DeviceModule {}

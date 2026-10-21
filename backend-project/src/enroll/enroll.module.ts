import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { DeviceAuthModule } from '../device-auth/device-auth.module.js';
import { EnrollController } from './enroll.controller.js';
import { EnrollService } from './enroll.service.js';

/**
 * Enrollment: invite → APK → complete. Depends on AuthModule for guards and
 * on DeviceAuthModule for minting the long-lived device JWT at /enroll/complete.
 */
@Module({
  imports: [AuthModule, DeviceAuthModule],
  controllers: [EnrollController],
  providers: [EnrollService],
  exports: [EnrollService],
})
export class EnrollModule {}

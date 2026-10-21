import { Global, Module } from '@nestjs/common';
import { FcmService } from './fcm.service.js';

/**
 * Global so admin/gateway/scheduler can inject FcmService without re-importing.
 * The service is a thin fan-out layer; it has no state that varies per module.
 */
@Global()
@Module({
  providers: [FcmService],
  exports: [FcmService],
})
export class FcmModule {}

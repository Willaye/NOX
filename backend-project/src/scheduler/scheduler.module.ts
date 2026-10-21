import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { GatewayModule } from '../gateway/gateway.module.js';
import { OfflineWatcherService } from './offline-watcher.service.js';

/**
 * Hosts background jobs. @nestjs/schedule's ScheduleModule.forRoot() lives
 * in AppModule so cron scanning is registered once globally.
 */
@Module({
  // MailService lives in AuthModule, NoxGateway in GatewayModule.
  imports: [AuthModule, GatewayModule],
  providers: [OfflineWatcherService],
  exports: [OfflineWatcherService],
})
export class SchedulerModule {}

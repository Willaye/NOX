import { Module } from '@nestjs/common';
import { AlertsService } from './alerts.service.js';
import { AlertsController } from './alerts.controller.js';

@Module({
  controllers: [AlertsController],
  providers: [AlertsService],
  exports: [AlertsService],
})
export class AlertsModule {}

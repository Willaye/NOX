import 'dotenv/config';
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './auth/auth.module.js';
import { DeviceModule } from './device/device.module.js';
import { DeviceAuthModule } from './device-auth/device-auth.module.js';
import { ActivityLogModule } from './activity-log/activity-log.module.js';
import { LocationLogModule } from './location-log/location-log.module.js';
import { TrackingModule } from './tracking/tracking.module.js';
import { GatewayModule } from './gateway/gateway.module.js';
import { AdminModule } from './admin/admin.module.js';
import { EnrollModule } from './enroll/enroll.module.js';
import { UsersModule } from './users/users.module.js';
import { FcmModule } from './fcm/fcm.module.js';
import { SchedulerModule } from './scheduler/scheduler.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Scheduler is registered once globally; individual modules can declare
    // @Cron handlers (see SchedulerModule).
    ScheduleModule.forRoot(),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    PrismaModule,
    FcmModule,
    GatewayModule,
    AuthModule,
    DeviceAuthModule,
    DeviceModule,
    ActivityLogModule,
    LocationLogModule,
    TrackingModule,
    AdminModule,
    EnrollModule,
    UsersModule,
    SchedulerModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

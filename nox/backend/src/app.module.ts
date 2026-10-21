import path from 'node:path';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { DevicesModule } from './devices/devices.module.js';
import { PairingModule } from './pairing/pairing.module.js';
import { SessionsModule } from './sessions/sessions.module.js';
import { FilesModule } from './files/files.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { MessagesModule } from './messages/messages.module.js';
import { AuditModule } from './audit/audit.module.js';
import { AlertsModule } from './alerts/alerts.module.js';
import { AdminModule } from './admin/admin.module.js';
import { HealthModule } from './health/health.module.js';
import { GatewayModule } from './gateway/gateway.module.js';
import { AppController } from './app.controller.js';

@Module({
  imports: [
    // Load the monorepo-level .env (nox/.env) when started from nox/backend
    ConfigModule.forRoot({
      envFilePath: path.join(process.cwd(), '..', '.env'),
      isGlobal: true,
    }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    PrismaModule,
    AuthModule,
    UsersModule,
    DevicesModule,
    PairingModule,
    SessionsModule,
    FilesModule,
    NotificationsModule,
    MessagesModule,
    AuditModule,
    AlertsModule,
    AdminModule,
    HealthModule,
    GatewayModule,
  ],
  controllers: [AppController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}

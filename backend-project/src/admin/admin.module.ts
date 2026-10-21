import { Module } from '@nestjs/common';
import { AdminService } from './admin.service.js';
import { AdminController } from './admin.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { GatewayModule } from '../gateway/gateway.module.js';

@Module({
  // AuthModule brings JwtAuthGuard. GatewayModule brings NoxGateway so
  // lock/unlock commands can be pushed in real-time. FcmModule is global.
  imports: [AuthModule, GatewayModule],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}

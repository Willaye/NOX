import { Global, Module } from '@nestjs/common';
import { NoxGateway } from './nox.gateway.js';
import { AuthModule } from '../auth/auth.module.js';

/**
 * Global so admin, tracking, and scheduler can inject the gateway for
 * broadcasts without re-importing GatewayModule everywhere.
 */
@Global()
@Module({
  imports: [AuthModule],
  providers: [NoxGateway],
  exports: [NoxGateway],
})
export class GatewayModule {}

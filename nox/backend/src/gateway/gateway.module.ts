import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { NoxGateway } from './nox.gateway.js';
import { getJwtSecret } from '../common/config/jwt.config.js';

@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: getJwtSecret(config),
      }),
    }),
  ],
  providers: [NoxGateway],
  exports: [NoxGateway],
})
export class GatewayModule {}

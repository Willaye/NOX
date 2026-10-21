import { Module } from '@nestjs/common';
import { PairingService } from './pairing.service.js';
import { PairingController } from './pairing.controller.js';

@Module({
  controllers: [PairingController],
  providers: [PairingService],
  exports: [PairingService],
})
export class PairingModule {}

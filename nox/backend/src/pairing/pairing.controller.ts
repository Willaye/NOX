import { Controller, Post, Get, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { PairingService } from './pairing.service.js';
import { GeneratePairingCodeDto, CompletePairingDto, ValidatePairingCodeDto } from './dto/pairing.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';

@UseGuards(JwtAuthGuard)
@Controller('pairing')
export class PairingController {
  constructor(private pairingService: PairingService) {}

  @Post('generate')
  generateCode(@CurrentUser('id') userId: string, @Body() dto: GeneratePairingCodeDto) {
    return this.pairingService.generateCode(userId, dto.deviceId);
  }

  @HttpCode(HttpStatus.OK)
  @Post('validate')
  validateCode(@Body() dto: ValidatePairingCodeDto) {
    return this.pairingService.validateCode(dto.code);
  }

  @HttpCode(HttpStatus.OK)
  @Post('complete')
  completePairing(@CurrentUser('id') userId: string, @Body() dto: CompletePairingDto) {
    return this.pairingService.completePairing(userId, dto.code, dto.deviceName);
  }

  @Get('active')
  getActiveCodes(@CurrentUser('id') userId: string) {
    return this.pairingService.getActiveCodes(userId);
  }
}

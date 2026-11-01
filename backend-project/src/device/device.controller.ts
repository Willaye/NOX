import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Request,
  UseGuards,
} from '@nestjs/common';
import { DeviceService } from './device.service.js';
import { CreateDeviceDto } from './dto/create-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';
import { PairDeviceDto } from './dto/pair-device.dto.js';
import { HeartbeatDto } from './dto/heartbeat.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { DeviceJwtGuard } from '../device-auth/device-jwt.guard.js';

@Controller('devices')
export class DeviceController {
  constructor(private deviceService: DeviceService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Request() req: any, @Body() dto: CreateDeviceDto) {
    return this.deviceService.createDevice(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('pair')
  pair(@Request() req: any, @Body() dto: PairDeviceDto) {
    return this.deviceService.pairDevice(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(@Request() req: any) {
    return this.deviceService.getDevices(req.user.id, req.user.role);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  findOne(@Request() req: any, @Param('id') id: string) {
    return this.deviceService.getDevice(req.user.id, id, req.user.role);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  update(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateDeviceDto,
  ) {
    return this.deviceService.updateDevice(req.user.id, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Request() req: any, @Param('id') id: string) {
    return this.deviceService.deleteDevice(req.user.id, id);
  }

  // Device agent calls this. Guarded by DeviceJwtGuard — the deviceId comes
  // from the token, not the URL. The :id path param is kept so URLs match
  // the old agent code, but we assert the URL id matches the token.
  @UseGuards(DeviceJwtGuard)
  @Post(':id/heartbeat')
  heartbeat(
    @Request() req: { device: { id: string } },
    @Param('id') urlId: string,
    @Body() dto: HeartbeatDto,
  ) {
    // Prefer the token identity. If someone intentionally uses the token for
    // a different device id in the URL, trust the token and ignore the URL.
    return this.deviceService.heartbeat(req.device.id || urlId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/regenerate-code')
  regenerateCode(@Request() req: any, @Param('id') id: string) {
    return this.deviceService.regeneratePairingCode(req.user.id, id);
  }

  // Agent calls this with its USER token to obtain a device JWT for an
  // already-registered device (needed for tracking uploads).
  @UseGuards(JwtAuthGuard)
  @Post(':id/token')
  issueToken(@Request() req: any, @Param('id') id: string) {
    return this.deviceService.issueDeviceToken(req.user.id, id, req.user.role);
  }

  // Device polls for pending commands (used when Flutter is dead but native service is running)
  @UseGuards(DeviceJwtGuard)
  @Get(':id/commands')
  getCommands(
    @Request() req: { device: { id: string } },
    @Param('id') urlId: string,
  ) {
    return this.deviceService.getPendingCommands(req.device.id || urlId);
  }
}

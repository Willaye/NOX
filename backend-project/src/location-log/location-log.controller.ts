import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { LocationLogService } from './location-log.service.js';
import {
  BatchCreateLocationLogDto,
  CreateLocationLogDto,
  QueryLocationLogDto,
} from './dto/location-log.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { AdminGuard } from '../admin/guards/admin.guard.js';
import { DeviceJwtGuard } from '../device-auth/device-jwt.guard.js';

@Controller('location-logs')
export class LocationLogController {
  constructor(private locationLogService: LocationLogService) {}

  @UseGuards(DeviceJwtGuard)
  @Post()
  create(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateLocationLogDto,
  ) {
    return this.locationLogService.create(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('batch')
  createBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchCreateLocationLogDto,
  ) {
    return this.locationLogService.createBatch(req.device.id, dto.logs);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('device/:deviceId')
  findByDevice(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryLocationLogDto,
  ) {
    return this.locationLogService.findByDevice(deviceId, query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('device/:deviceId/latest')
  getLatest(@Param('deviceId') deviceId: string) {
    return this.locationLogService.getLatest(deviceId);
  }
}

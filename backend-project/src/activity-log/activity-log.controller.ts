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
import { ActivityLogService } from './activity-log.service.js';
import {
  BatchCreateActivityLogDto,
  CreateActivityLogDto,
  QueryActivityLogDto,
} from './dto/activity-log.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { AdminGuard } from '../admin/guards/admin.guard.js';
import { DeviceJwtGuard } from '../device-auth/device-jwt.guard.js';

@Controller('activity-logs')
export class ActivityLogController {
  constructor(private activityLogService: ActivityLogService) {}

  @UseGuards(DeviceJwtGuard)
  @Post()
  create(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateActivityLogDto,
  ) {
    return this.activityLogService.create(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('batch')
  createBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchCreateActivityLogDto,
  ) {
    return this.activityLogService.createBatch(req.device.id, dto.logs);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('device/:deviceId')
  findByDevice(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryActivityLogDto,
  ) {
    return this.activityLogService.findByDevice(deviceId, query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('device/:deviceId/stats')
  getStats(@Param('deviceId') deviceId: string) {
    return this.activityLogService.getStats(deviceId);
  }
}

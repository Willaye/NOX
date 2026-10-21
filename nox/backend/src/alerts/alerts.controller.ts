import { Controller, Get, Post, Delete, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { AlertsService } from './alerts.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { AlertsQueryDto } from './dto/alerts-query.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('alerts')
export class AlertsController {
  constructor(private alertsService: AlertsService) {}

  @Get()
  findAll(@CurrentUser('id') userId: string, @Query() query: AlertsQueryDto) {
    return this.alertsService.findAllByUser(userId, {
      page: query.page,
      limit: query.limit,
      deviceId: query.deviceId,
      type: query.type,
      severity: query.severity,
      resolved: query.isResolved ?? query.resolved,
    });
  }

  @Get('stats')
  getStats(@CurrentUser('id') userId: string) {
    return this.alertsService.getStats(userId);
  }

  @Get(':id')
  findById(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.alertsService.findById(userId, id);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/resolve')
  resolve(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.alertsService.resolve(userId, id);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/acknowledge')
  acknowledge(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.alertsService.acknowledge(userId, id);
  }

  @Delete(':id')
  delete(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.alertsService.delete(userId, id);
  }
}

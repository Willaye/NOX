import { Controller, Get, Post, Body, Param, Query, UseGuards, HttpCode, HttpStatus, Ip } from '@nestjs/common';
import { SessionsService } from './sessions.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { PaginationDto } from '../common/dto/pagination.dto.js';
import { StartSessionDto } from './dto/sessions.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('sessions')
export class SessionsController {
  constructor(private sessionsService: SessionsService) {}

  @Post('start')
  startSession(
    @CurrentUser('id') userId: string,
    @Body() dto: StartSessionDto,
    @Ip() ip: string,
  ) {
    return this.sessionsService.startSession(userId, dto.deviceId, ip);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/end')
  endSession(@CurrentUser('id') userId: string, @Param('id') sessionId: string) {
    return this.sessionsService.endSession(userId, sessionId);
  }

  @Get('device/:deviceId/active')
  getActiveByDevice(@CurrentUser('id') userId: string, @Param('deviceId') deviceId: string) {
    return this.sessionsService.getActiveSessionsByDevice(userId, deviceId);
  }

  @Get('device/:deviceId/history')
  getHistory(
    @CurrentUser('id') userId: string,
    @Param('deviceId') deviceId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.sessionsService.getSessionHistory(userId, deviceId, {
      page: pagination.page,
      limit: pagination.limit,
    });
  }

  @Get('active')
  getUserActiveSessions(@CurrentUser('id') userId: string) {
    return this.sessionsService.getUserActiveSessions(userId);
  }
}

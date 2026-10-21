import { Controller, Get, Post, Delete, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { NotificationsService } from './notifications.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { NotificationsQueryDto } from './dto/notifications-query.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  findAll(@CurrentUser('id') userId: string, @Query() query: NotificationsQueryDto) {
    return this.notificationsService.findAllByUser(userId, {
      page: query.page,
      limit: query.limit,
      unreadOnly: query.unreadOnly === true,
    });
  }

  @Get('unread-count')
  getUnreadCount(@CurrentUser('id') userId: string) {
    return this.notificationsService.getUnreadCount(userId);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/read')
  markAsRead(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.notificationsService.markAsRead(userId, id);
  }

  @HttpCode(HttpStatus.OK)
  @Post('read-all')
  markAllAsRead(@CurrentUser('id') userId: string) {
    return this.notificationsService.markAllAsRead(userId);
  }

  @Delete(':id')
  delete(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.notificationsService.delete(userId, id);
  }
}

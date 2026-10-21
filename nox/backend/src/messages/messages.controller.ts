import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { MessagesService } from './messages.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { PaginationDto } from '../common/dto/pagination.dto.js';
import { SendMessageDto } from './dto/messages.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessagesController {
  constructor(private messagesService: MessagesService) {}

  @Post()
  send(@CurrentUser('id') senderId: string, @Body() dto: SendMessageDto) {
    return this.messagesService.send({
      senderId,
      receiverId: dto.receiverId,
      deviceId: dto.deviceId,
      type: dto.type ?? 'TEXT',
      content: dto.content,
    });
  }

  @Get('inbox')
  getInbox(@CurrentUser('id') userId: string, @Query() pagination: PaginationDto) {
    return this.messagesService.getInbox(userId, { page: pagination.page, limit: pagination.limit });
  }

  @Get('conversation/:userId')
  getConversation(
    @CurrentUser('id') userId: string,
    @Param('userId') otherUserId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.messagesService.getConversation(userId, otherUserId, {
      page: pagination.page,
      limit: pagination.limit,
    });
  }

  @Get('device/:deviceId')
  getDeviceMessages(
    @CurrentUser('id') userId: string,
    @Param('deviceId') deviceId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.messagesService.getDeviceMessages(userId, deviceId, {
      page: pagination.page,
      limit: pagination.limit,
    });
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/read')
  markAsRead(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.messagesService.markAsRead(userId, id);
  }

  @Delete(':id')
  delete(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.messagesService.deleteMessage(userId, id);
  }
}

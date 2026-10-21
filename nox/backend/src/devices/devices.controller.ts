import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { DevicesService } from './devices.service.js';
import { CreateDeviceDto, UpdateDeviceDto, HeartbeatDto } from './dto/devices.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { PaginationDto } from '../common/dto/pagination.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('devices')
export class DevicesController {
  constructor(private devicesService: DevicesService) {}

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateDeviceDto) {
    return this.devicesService.create(userId, dto);
  }

  @Get()
  findAll(@CurrentUser('id') userId: string, @Query() pagination: PaginationDto) {
    return this.devicesService.findAllByUser(userId, { page: pagination.page, limit: pagination.limit });
  }

  @Get(':id')
  findById(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.devicesService.findById(id, userId);
  }

  @Put(':id')
  update(@Param('id') id: string, @CurrentUser('id') userId: string, @Body() dto: UpdateDeviceDto) {
    return this.devicesService.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.devicesService.remove(id, userId);
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/heartbeat')
  heartbeat(@Param('id') id: string, @CurrentUser('id') userId: string, @Body() dto: HeartbeatDto) {
    return this.devicesService.heartbeat(id, userId, dto);
  }
}

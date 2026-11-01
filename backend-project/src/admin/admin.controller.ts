import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { AdminService } from './admin.service.js';
import {
  AddDeviceDto,
  DeviceQueryDto,
  EmployeeQueryDto,
  RegisterFcmTokenDto,
} from './dto/admin.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { AdminGuard } from './guards/admin.guard.js';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('dashboard')
  getDashboard(@Request() req: any) {
    return this.adminService.getDashboard(req.user.id);
  }

  // ─── Devices ────────────────────────────────────────────────────────────

  // Legacy: creates an unpaired device without sending an invite. New admin
  // UIs should call POST /enroll/invite instead.
  @Post('devices/add')
  addDevice(@Request() req: any, @Body() dto: AddDeviceDto) {
    return this.adminService.addDevice(dto.email, req.user.id);
  }

  @Get('devices')
  getDevices(@Request() req: any, @Query() query: DeviceQueryDto) {
    return this.adminService.getAllDevices(req.user.id, query);
  }

  // Returns header + latest sample from each category. For paginated per-
  // category reads, use the dedicated /tracking/* and /location-logs/*
  // endpoints (admin-guarded).
  @Get('devices/:id')
  getDeviceOverview(@Request() req: any, @Param('id') id: string) {
    return this.adminService.getDeviceOverview(id, req.user.id);
  }

  @Post('devices/:id/lock')
  lockDevice(@Request() req: any, @Param('id') id: string) {
    return this.adminService.lockDevice(id, req.user.id);
  }

  @Post('devices/:id/unlock')
  unlockDevice(@Request() req: any, @Param('id') id: string) {
    return this.adminService.unlockDevice(id, req.user.id);
  }

  @Post('devices/:id/uninstall')
  requestUninstall(@Request() req: any, @Param('id') id: string) {
    return this.adminService.requestUninstall(id, req.user.id);
  }

  @Delete('devices/:id')
  removeDevice(@Param('id') id: string) {
    return this.adminService.removeDevice(id);
  }

  @Get('devices/:id/commands')
  getCommandHistory(@Param('id') id: string) {
    return this.adminService.getCommandHistory(id);
  }

  // ─── Employees ──────────────────────────────────────────────────────────

  @Get('employees')
  getEmployees(@Request() req: any, @Query() query: EmployeeQueryDto) {
    return this.adminService.getAllEmployees(req.user.id, query);
  }

  // ─── Notifications ──────────────────────────────────────────────────────

  @Get('notifications')
  getNotifications() {
    return this.adminService.getNotifications();
  }

  @Get('notifications/unread-count')
  getUnreadCount() {
    return this.adminService.getUnreadCount();
  }

  @Post('notifications/:id/read')
  markRead(@Param('id') id: string) {
    return this.adminService.markNotificationRead(id);
  }

  @Post('notifications/read-all')
  markAllRead() {
    return this.adminService.markAllRead();
  }

  // ─── Admin FCM token registration ───────────────────────────────────────

  @Post('me/fcm-token')
  registerFcmToken(@Request() req: any, @Body() dto: RegisterFcmTokenDto) {
    return this.adminService.registerFcmToken(req.user.id, dto.fcmToken);
  }

  @Delete('me/fcm-token')
  clearFcmToken(@Request() req: any) {
    return this.adminService.clearFcmToken(req.user.id);
  }
}

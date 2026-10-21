import { Controller, Get, Put, Delete, Param, Query, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { AdminService } from './admin.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard, Roles } from '../common/guards/roles.guard.js';
import {
  AdminUsersQueryDto,
  AdminDevicesQueryDto,
  AdminAlertsQueryDto,
  AdminAuditLogsQueryDto,
  ToggleUserActiveDto,
} from './dto/admin.dto.js';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'SUPER_ADMIN')
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('dashboard')
  getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  @Get('users')
  getUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.getUsers({
      page: query.page,
      limit: query.limit,
      search: query.search,
      isActive: query.isActive,
    });
  }

  @Get('devices')
  getDevices(@Query() query: AdminDevicesQueryDto) {
    return this.adminService.getDevices({
      page: query.page,
      limit: query.limit,
      search: query.search,
      isOnline: query.isOnline,
      userId: query.userId,
    });
  }

  @Get('alerts')
  getAlerts(@Query() query: AdminAlertsQueryDto) {
    return this.adminService.getAlerts({
      page: query.page,
      limit: query.limit,
      type: query.type,
      severity: query.severity,
      isResolved: query.isResolved,
    });
  }

  @HttpCode(HttpStatus.OK)
  @Put('users/:id/toggle-active')
  toggleUserActive(@Param('id') id: string, @Body() dto: ToggleUserActiveDto) {
    return this.adminService.toggleUserActive(id, dto.isActive);
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string) {
    return this.adminService.deleteUser(id);
  }

  @Get('audit-logs')
  getRecentAuditLogs(@Query() query: AdminAuditLogsQueryDto) {
    return this.adminService.getRecentAuditLogs(query.limit ?? 20);
  }
}

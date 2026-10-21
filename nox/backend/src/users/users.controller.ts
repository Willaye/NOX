import { Controller, Get, Put, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { UsersService } from './users.service.js';
import { UpdateUserDto, ChangePasswordDto, AdminUpdateUserDto } from './dto/users.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard, Roles } from '../common/guards/roles.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { UsersQueryDto } from './dto/users-query.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @UseGuards(RolesGuard)
  @Roles('ADMIN', 'SUPER_ADMIN')
  @Get()
  findAll(@Query() query: UsersQueryDto) {
    return this.usersService.findAll({
      page: query.page,
      limit: query.limit,
      search: query.search,
      isActive: query.isActive,
    });
  }

  @Get(':id')
  findById(@Param('id') id: string, @CurrentUser() user: { id: string; roles: string[] }) {
    if (user.id !== id && !user.roles.some((r: string) => ['ADMIN', 'SUPER_ADMIN'].includes(r))) {
      return this.usersService.findById(user.id);
    }
    return this.usersService.findById(id);
  }

  @Put('me')
  updateMe(@CurrentUser('id') userId: string, @Body() dto: UpdateUserDto) {
    return this.usersService.update(userId, dto);
  }

  @HttpCode(HttpStatus.OK)
  @Put('me/password')
  changePassword(@CurrentUser('id') userId: string, @Body() dto: ChangePasswordDto) {
    return this.usersService.changePassword(userId, dto);
  }

  @UseGuards(RolesGuard)
  @Roles('ADMIN', 'SUPER_ADMIN')
  @Put(':id')
  adminUpdate(@Param('id') id: string, @Body() dto: AdminUpdateUserDto) {
    return this.usersService.adminUpdate(id, dto);
  }

  @UseGuards(RolesGuard)
  @Roles('ADMIN', 'SUPER_ADMIN')
  @Delete(':id')
  softDelete(@Param('id') id: string) {
    return this.usersService.softDelete(id);
  }
}

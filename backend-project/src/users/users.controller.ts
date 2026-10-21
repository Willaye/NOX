import { Body, Controller, Put, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { UsersService } from './users.service.js';
import { ChangePasswordDto } from './dto/users.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  /**
   * Route path matches what the existing Flutter admin app expects (see
   * api_client.dart: `PUT /users/me/password`). The health check previously
   * flagged this call as a 404; this controller closes that gap.
   */
  @Put('me/password')
  changePassword(
    @Request() req: { user: { id: string } },
    @Body() dto: ChangePasswordDto,
  ) {
    return this.users.changePassword(
      req.user.id,
      dto.currentPassword,
      dto.newPassword,
    );
  }
}

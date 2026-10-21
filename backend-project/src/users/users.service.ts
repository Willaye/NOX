import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Set or change the current user's password.
   *
   * Two modes:
   *   1. User already has a passwordHash → verify currentPassword first.
   *   2. User was created via magic-link enrollment (no passwordHash yet)
   *      → first-time set, currentPassword is ignored.
   */
  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ) {
    if (newPassword.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.passwordHash) {
      const ok = await bcrypt.compare(currentPassword, user.passwordHash);
      if (!ok) throw new UnauthorizedException('Current password is incorrect');
    }

    const newHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });
    return { ok: true };
  }
}

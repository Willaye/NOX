import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service.js';
import { UpdateUserDto, ChangePasswordDto, AdminUpdateUserDto } from './dto/users.dto.js';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll(params: { page?: number; limit?: number; search?: string; isActive?: boolean }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = { deletedAt: null };
    if (params.isActive !== undefined) where.isActive = params.isActive;
    if (params.search) {
      where.OR = [
        { email: { contains: params.search, mode: 'insensitive' } },
        { firstName: { contains: params.search, mode: 'insensitive' } },
        { lastName: { contains: params.search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          avatarUrl: true,
          isActive: true,
          emailVerified: true,
          lastLoginAt: true,
          createdAt: true,
          userRoles: { include: { role: { select: { name: true } } } },
          _count: { select: { devices: true } },
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      data: data.map((u: any) => ({
        ...u,
        roles: u.userRoles.map((ur: any) => ur.role.name),
        userRoles: undefined,
        deviceCount: u._count.devices,
        _count: undefined,
      })),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id, deletedAt: null },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        isActive: true,
        emailVerified: true,
        lastLoginAt: true,
        createdAt: true,
        userRoles: { include: { role: { select: { name: true } } } },
        devices: {
          where: { deletedAt: null },
          select: { id: true, name: true, deviceType: true, platform: true, isOnline: true, lastSeenAt: true },
        },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return {
      ...user,
      roles: user.userRoles.map((ur: any) => ur.role.name),
      userRoles: undefined,
    };
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.ensureExists(id);
    return this.prisma.user.update({
      where: { id },
      data: dto,
      select: { id: true, email: true, firstName: true, lastName: true, avatarUrl: true },
    });
  }

  async changePassword(id: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id, deletedAt: null } });
    if (!user) throw new NotFoundException('User not found');

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) throw new BadRequestException('Current password is incorrect');

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.prisma.user.update({ where: { id }, data: { passwordHash } });
    return { message: 'Password changed successfully' };
  }

  async adminUpdate(id: string, dto: AdminUpdateUserDto) {
    await this.ensureExists(id);
    return this.prisma.user.update({
      where: { id },
      data: dto,
      select: { id: true, email: true, firstName: true, lastName: true, isActive: true, emailVerified: true },
    });
  }

  async softDelete(id: string) {
    await this.ensureExists(id);
    await this.prisma.user.update({ where: { id }, data: { deletedAt: new Date(), isActive: false } });
    return { message: 'User deleted' };
  }

  private async ensureExists(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id, deletedAt: null } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }
}

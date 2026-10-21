import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  async getDashboardStats() {
    const [
      totalUsers,
      activeUsers,
      totalDevices,
      onlineDevices,
      totalSessions,
      activeSessions,
      totalAlerts,
      unresolvedAlerts,
    ] = await Promise.all([
      this.prisma.user.count({ where: { deletedAt: null } }),
      this.prisma.user.count({ where: { deletedAt: null, isActive: true } }),
      this.prisma.device.count({ where: { deletedAt: null } }),
      this.prisma.device.count({ where: { deletedAt: null, isOnline: true } }),
      this.prisma.deviceSession.count(),
      this.prisma.deviceSession.count({ where: { disconnectedAt: null } }),
      this.prisma.alert.count(),
      this.prisma.alert.count({ where: { resolvedAt: null } }),
    ]);

    // Recent signups (last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const recentSignups = await this.prisma.user.count({
      where: { createdAt: { gte: sevenDaysAgo }, deletedAt: null },
    });

    return {
      users: { total: totalUsers, active: activeUsers, recentSignups },
      devices: { total: totalDevices, online: onlineDevices },
      sessions: { total: totalSessions, active: activeSessions },
      alerts: { total: totalAlerts, unresolved: unresolvedAlerts },
    };
  }

  async getUsers(params: { page?: number; limit?: number; search?: string; isActive?: boolean }) {
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

  async getDevices(params: { page?: number; limit?: number; search?: string; isOnline?: boolean; userId?: string }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = { deletedAt: null };
    if (params.isOnline !== undefined) where.isOnline = params.isOnline;
    if (params.userId) where.ownerId = params.userId;
    if (params.search) {
      where.OR = [
        { name: { contains: params.search, mode: 'insensitive' } },
        { model: { contains: params.search, mode: 'insensitive' } },
        { manufacturer: { contains: params.search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.device.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          owner: { select: { id: true, email: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.device.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getAlerts(params: { page?: number; limit?: number; type?: string; severity?: string; isResolved?: boolean }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = {};
    if (params.type) where.type = params.type;
    if (params.severity) where.severity = params.severity;
    if (params.isResolved !== undefined) {
      where.resolvedAt = params.isResolved ? { not: null } : null;
    }

    const [data, total] = await Promise.all([
      this.prisma.alert.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { device: { select: { id: true, name: true, deviceType: true } } },
      }),
      this.prisma.alert.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async toggleUserActive(userId: string, isActive: boolean) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { isActive },
      select: { id: true, email: true, isActive: true },
    });
  }

  async deleteUser(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { deletedAt: new Date(), isActive: false },
    });
    return { message: 'User deleted' };
  }

  async getRecentAuditLogs(limit = 20) {
    return this.prisma.auditLog.findMany({
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: { actor: { select: { id: true, email: true, firstName: true, lastName: true } } },
    });
  }
}

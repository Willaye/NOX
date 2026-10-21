import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';


@Injectable()
export class AlertsService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    userId: string;
    deviceId: string;
    type: string;
    severity: string;
    title: string;
    message?: string;
    metadata?: Record<string, unknown>;
  }) {
    return this.prisma.alert.create({
      data: {
        userId: data.userId,
        deviceId: data.deviceId,
        type: data.type as any,
        severity: (data.severity || 'INFO') as any,
        title: data.title,
        message: data.message || '',
        data: data.metadata ? JSON.parse(JSON.stringify(data.metadata)) : undefined,
      },
    });
  }

  async findAllByUser(userId: string, params: {
    page?: number;
    limit?: number;
    deviceId?: string;
    type?: string;
    severity?: string;
    resolved?: boolean;
  }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = { userId };
    if (params.deviceId) where.deviceId = params.deviceId;
    if (params.type) where.type = params.type as any;
    if (params.severity) where.severity = params.severity as any;
    if (params.resolved !== undefined) {
      where.resolvedAt = params.resolved ? { not: null } : null;
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

  async findById(userId: string, alertId: string) {
    const alert = await this.prisma.alert.findUnique({
      where: { id: alertId },
      include: { device: { select: { id: true, name: true, deviceType: true, platform: true } } },
    });
    if (!alert) throw new NotFoundException('Alert not found');
    if (alert.userId !== userId) throw new ForbiddenException('Not your alert');
    return alert;
  }

  async resolve(userId: string, alertId: string) {
    await this.findById(userId, alertId);
    return this.prisma.alert.update({
      where: { id: alertId },
      data: { resolvedAt: new Date() },
    });
  }

  async acknowledge(userId: string, alertId: string) {
    await this.findById(userId, alertId);
    return this.prisma.alert.update({
      where: { id: alertId },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async delete(userId: string, alertId: string) {
    await this.findById(userId, alertId);
    await this.prisma.alert.delete({ where: { id: alertId } });
    return { message: 'Alert deleted' };
  }

  async getStats(userId: string) {
    const [total, unresolved, critical, warning] = await Promise.all([
      this.prisma.alert.count({ where: { userId } }),
      this.prisma.alert.count({ where: { userId, resolvedAt: null } }),
      this.prisma.alert.count({ where: { userId, severity: 'CRITICAL' as any, resolvedAt: null } }),
      this.prisma.alert.count({ where: { userId, severity: 'WARNING' as any, resolvedAt: null } }),
    ]);
    return { total, unresolved, critical, warning };
  }
}

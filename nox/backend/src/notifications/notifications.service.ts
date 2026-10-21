import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';


@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async create(data: {
    userId: string;
    title: string;
    body: string;
    type?: string;
    deviceId?: string;
    metadata?: Record<string, unknown>;
  }) {
    return this.prisma.notification.create({
      data: {
        userId: data.userId,
        title: data.title,
        body: data.body,
        type: (data.type || 'SYSTEM') as any,
        deviceId: data.deviceId,
        data: data.metadata ? JSON.parse(JSON.stringify(data.metadata)) : undefined,
      },
    });
  }

  async findAllByUser(userId: string, params: { page?: number; limit?: number; unreadOnly?: boolean }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = { userId };
    if (params.unreadOnly) where.isRead = false;

    const [data, total, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { device: { select: { id: true, name: true } } },
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { userId, isRead: false } }),
    ]);

    return {
      data,
      unreadCount,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async markAsRead(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findUnique({ where: { id: notificationId } });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.userId !== userId) throw new ForbiddenException('Not your notification');

    return this.prisma.notification.update({
      where: { id: notificationId },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async markAllAsRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return { marked: result.count };
  }

  async delete(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findUnique({ where: { id: notificationId } });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.userId !== userId) throw new ForbiddenException('Not your notification');

    await this.prisma.notification.delete({ where: { id: notificationId } });
    return { message: 'Notification deleted' };
  }

  async getUnreadCount(userId: string) {
    const count = await this.prisma.notification.count({ where: { userId, isRead: false } });
    return { unreadCount: count };
  }
}

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';


@Injectable()
export class MessagesService {
  constructor(private prisma: PrismaService) {}

  async send(data: {
    senderId: string;
    receiverId: string;
    deviceId?: string;
    type: string;
    content: string;
  }) {
    // Verify recipient exists
    const recipient = await this.prisma.user.findUnique({ where: { id: data.receiverId, deletedAt: null } });
    if (!recipient) throw new NotFoundException('Recipient not found');

    return this.prisma.message.create({
      data: {
        senderId: data.senderId,
        receiverId: data.receiverId,
        deviceId: data.deviceId,
        contentType: (data.type || 'TEXT') as any,
        content: data.content,
      },
    });
  }

  async getConversation(userId: string, otherUserId: string, params: { page?: number; limit?: number }) {
    const page = params.page || 1;
    const limit = params.limit || 50;
    const skip = (page - 1) * limit;

    const where = {
      OR: [
        { senderId: userId, receiverId: otherUserId },
        { senderId: otherUserId, receiverId: userId },
      ],
      deletedAt: null,
    };

    const [data, total] = await Promise.all([
      this.prisma.message.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          sender: { select: { id: true, email: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.message.count({ where }),
    ]);

    // Mark received messages as read
    await this.prisma.message.updateMany({
      where: { senderId: otherUserId, receiverId: userId, readAt: null },
      data: { readAt: new Date(), status: 'READ' },
    });

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getDeviceMessages(userId: string, deviceId: string, params: { page?: number; limit?: number }) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    const page = params.page || 1;
    const limit = params.limit || 50;
    const skip = (page - 1) * limit;

    const where = { deviceId, deletedAt: null };

    const [data, total] = await Promise.all([
      this.prisma.message.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          sender: { select: { id: true, email: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.message.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getInbox(userId: string, params: { page?: number; limit?: number }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where = { receiverId: userId, deletedAt: null };

    const [data, total, unreadCount] = await Promise.all([
      this.prisma.message.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          sender: { select: { id: true, email: true, firstName: true, lastName: true } },
          device: { select: { id: true, name: true } },
        },
      }),
      this.prisma.message.count({ where }),
      this.prisma.message.count({ where: { ...where, readAt: null } }),
    ]);

    return {
      data,
      unreadCount,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async markAsRead(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) throw new NotFoundException('Message not found');
    if (message.receiverId !== userId) throw new ForbiddenException('Not your message');

    return this.prisma.message.update({
      where: { id: messageId },
      data: { readAt: new Date(), status: 'READ' },
    });
  }

  async deleteMessage(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) throw new NotFoundException('Message not found');
    if (message.senderId !== userId && message.receiverId !== userId) {
      throw new ForbiddenException('Not your message');
    }

    await this.prisma.message.update({ where: { id: messageId }, data: { deletedAt: new Date() } });
    return { message: 'Message deleted' };
  }
}

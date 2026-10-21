import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class SessionsService {
  constructor(private prisma: PrismaService) {}

  async startSession(userId: string, deviceId: string, ipAddress?: string) {
    // Verify ownership
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    // End any existing active sessions for this device
    await this.prisma.deviceSession.updateMany({
      where: { deviceId, disconnectedAt: null },
      data: { disconnectedAt: new Date() },
    });

    const session = await this.prisma.deviceSession.create({
      data: {
        deviceId,
        ipAddress,
        connectedAt: new Date(),
      },
    });

    // Mark device online
    await this.prisma.device.update({
      where: { id: deviceId },
      data: { isOnline: true, lastSeenAt: new Date() },
    });

    return session;
  }

  async endSession(userId: string, sessionId: string) {
    const session = await this.prisma.deviceSession.findUnique({
      where: { id: sessionId },
      include: { device: true },
    });
    if (!session) throw new NotFoundException('Session not found');
    if (session.device.ownerId !== userId) throw new ForbiddenException('Not your session');

    const updated = await this.prisma.deviceSession.update({
      where: { id: sessionId },
      data: { disconnectedAt: new Date() },
    });

    // Check if device has other active sessions
    const activeSessions = await this.prisma.deviceSession.count({
      where: { deviceId: session.deviceId, disconnectedAt: null },
    });
    if (activeSessions === 0) {
      await this.prisma.device.update({
        where: { id: session.deviceId },
        data: { isOnline: false },
      });
    }

    return updated;
  }

  async getActiveSessionsByDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    return this.prisma.deviceSession.findMany({
      where: { deviceId, disconnectedAt: null },
      orderBy: { connectedAt: 'desc' },
    });
  }

  async getSessionHistory(userId: string, deviceId: string, params: { page?: number; limit?: number }) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.deviceSession.findMany({
        where: { deviceId },
        skip,
        take: limit,
        orderBy: { connectedAt: 'desc' },
      }),
      this.prisma.deviceSession.count({ where: { deviceId } }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getUserActiveSessions(userId: string) {
    return this.prisma.deviceSession.findMany({
      where: {
        device: { ownerId: userId },
        disconnectedAt: null,
      },
      include: {
        device: { select: { id: true, name: true, deviceType: true, platform: true } },
      },
      orderBy: { connectedAt: 'desc' },
    });
  }
}

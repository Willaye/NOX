import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';


@Injectable()
export class PairingService {
  constructor(private prisma: PrismaService) {}

  async generateCode(userId: string, deviceId: string) {
    // Verify device ownership
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    // Invalidate existing pending sessions for this device
    await this.prisma.pairingSession.updateMany({
      where: { deviceId, status: 'PENDING' as any, expiresAt: { gt: new Date() } },
      data: { status: 'CANCELLED' as any },
    });

    // Generate a 6-character alphanumeric code
    const code = this.generateAlphanumericCode(6);
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 15); // 15 min expiry

    const pairingSession = await this.prisma.pairingSession.create({
      data: {
        code,
        deviceId,
        initiatorId: userId,
        expiresAt,
        status: 'PENDING' as any,
      },
    });

    return {
      code: pairingSession.code,
      deviceId: pairingSession.deviceId,
      expiresAt: pairingSession.expiresAt,
    };
  }

  async validateCode(code: string) {
    const pairingSession = await this.prisma.pairingSession.findFirst({
      where: {
        code: code.toUpperCase(),
        status: 'PENDING' as any,
        expiresAt: { gt: new Date() },
      },
      include: {
        device: { select: { id: true, name: true, deviceType: true, platform: true } },
      },
    });

    if (!pairingSession) throw new BadRequestException('Invalid or expired pairing code');

    return {
      valid: true,
      device: pairingSession.device,
      expiresAt: pairingSession.expiresAt,
    };
  }

  async completePairing(userId: string, code: string, deviceName?: string) {
    const normalizedCode = code.toUpperCase();

    // Run lookup, claim and device update atomically so a code can only be redeemed once.
    return this.prisma.$transaction(async (tx) => {
      const pairingSession = await tx.pairingSession.findFirst({
        where: {
          code: normalizedCode,
          status: 'PENDING' as any,
          expiresAt: { gt: new Date() },
        },
        include: { device: true },
      });

      if (!pairingSession) throw new BadRequestException('Invalid or expired pairing code');
      if (!pairingSession.deviceId || !pairingSession.device || pairingSession.device.deletedAt) {
        throw new BadRequestException('No device associated with this pairing session');
      }

      // Only the device owner may approve a pairing for their device
      if (pairingSession.device.ownerId !== userId) {
        throw new ForbiddenException('Only the device owner can approve this pairing');
      }

      // Conditional claim: if a concurrent request already completed/cancelled it, count is 0
      const claimed = await tx.pairingSession.updateMany({
        where: { id: pairingSession.id, status: 'PENDING' as any, expiresAt: { gt: new Date() } },
        data: { status: 'COMPLETED' as any, completedAt: new Date() },
      });
      if (claimed.count !== 1) throw new BadRequestException('Invalid or expired pairing code');

      const device = await tx.device.update({
        where: { id: pairingSession.deviceId },
        data: {
          name: deviceName || pairingSession.device.name || 'Paired Device',
          isPaired: true,
        },
        select: {
          id: true,
          name: true,
          deviceType: true,
          platform: true,
          isPaired: true,
        },
      });

      return { message: 'Device paired successfully', device };
    });
  }

  async getActiveCodes(userId: string) {
    return this.prisma.pairingSession.findMany({
      where: {
        initiatorId: userId,
        status: 'PENDING' as any,
        expiresAt: { gt: new Date() },
      },
      select: {
        id: true,
        code: true,
        expiresAt: true,
        device: { select: { id: true, name: true, deviceType: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private generateAlphanumericCode(length: number): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 0, 1 to avoid confusion
    let result = '';
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    for (let i = 0; i < length; i++) {
      result += chars[bytes[i] % chars.length];
    }
    return result;
  }
}

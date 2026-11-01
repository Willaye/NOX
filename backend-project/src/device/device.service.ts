import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { DeviceJwtService } from '../device-auth/device-jwt.service.js';
import { CreateDeviceDto } from './dto/create-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';
import { PairDeviceDto } from './dto/pair-device.dto.js';
import { HeartbeatDto } from './dto/heartbeat.dto.js';
import { randomBytes } from 'crypto';

const MAX_PAIRING_CODE_ATTEMPTS = 5;

function isPrismaError(err: unknown, code: string): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === code;
}

@Injectable()
export class DeviceService {
  constructor(
    private prisma: PrismaService,
    private deviceJwt: DeviceJwtService,
  ) {}

  private generatePairingCode(): string {
    return randomBytes(3).toString('hex').toUpperCase();
  }

  /**
   * Runs `op` with a freshly generated pairing code, retrying when the code
   * collides with an existing one (unique constraint violation on pairingCode).
   */
  private async withUniquePairingCode<T>(op: (code: string) => Promise<T>): Promise<T> {
    for (let attempt = 1; attempt <= MAX_PAIRING_CODE_ATTEMPTS; attempt++) {
      try {
        return await op(this.generatePairingCode());
      } catch (err) {
        const isCodeCollision =
          isPrismaError(err, 'P2002') &&
          JSON.stringify((err as Prisma.PrismaClientKnownRequestError).meta?.target ?? '').includes('pairingCode');
        if (!isCodeCollision || attempt === MAX_PAIRING_CODE_ATTEMPTS) {
          if (isCodeCollision) {
            throw new ConflictException('Could not generate a unique pairing code, please retry');
          }
          throw err;
        }
      }
    }
    // Unreachable: loop either returns or throws
    throw new ConflictException('Could not generate a unique pairing code, please retry');
  }

  async createDevice(ownerId: string, dto: CreateDeviceDto) {
    const device = await this.withUniquePairingCode((pairingCode) =>
      this.prisma.device.create({
        data: { name: dto.name, ownerId, pairingCode, isPaired: false, isOnline: false },
      }),
    );
    // Mint a device JWT so the agent can authenticate its tracking uploads
    // (which are protected by DeviceJwtGuard, not the user JWT).
    const deviceToken = this.deviceJwt.sign(device.id, ownerId);
    return { id: device.id, name: device.name, pairingCode: device.pairingCode, isPaired: device.isPaired, isOnline: device.isOnline, createdAt: device.createdAt, deviceToken };
  }

  /**
   * Issue (or re-issue) a device JWT for an already-registered device. The
   * agent calls this with its USER token on startup when it doesn't yet hold a
   * device token (e.g. the device was registered before device-tokens existed,
   * or after a reinstall). Only the device owner (or an admin) may mint it.
   */
  async issueDeviceToken(userId: string, deviceId: string, role?: string) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId } });
    if (!device) throw new NotFoundException('Device not found');
    if (role !== 'ADMIN' && device.ownerId !== userId) {
      throw new ForbiddenException('Access denied');
    }
    return {
      deviceToken: this.deviceJwt.sign(device.id, device.ownerId ?? undefined),
    };
  }

  async pairDevice(userId: string, dto: PairDeviceDto) {
    const device = await this.prisma.device.findUnique({ where: { pairingCode: dto.pairingCode } });
    if (!device) throw new NotFoundException('Invalid pairing code');
    if (device.isPaired) throw new BadRequestException('Device is already paired');
    if (device.ownerId !== userId) throw new ForbiddenException('This device does not belong to you');
    const updated = await this.prisma.device.update({ where: { id: device.id }, data: { isPaired: true, pairingCode: null } });
    return { id: updated.id, name: updated.name, isPaired: updated.isPaired, isOnline: updated.isOnline, createdAt: updated.createdAt };
  }

  async getDevices(userId: string, role?: string) {
    // An ADMIN monitors every enrolled device, including ones registered
    // under employees' own accounts. Non-admins only see devices they own.
    const where = role === 'ADMIN' ? {} : { ownerId: userId };
    return this.prisma.device.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        isPaired: true,
        isOnline: true,
        lastSeenAt: true,
        batteryLevel: true,
        lockStatus: true,
        employeeEmail: true,
        createdAt: true,
      },
    });
  }

  async getDevice(userId: string, deviceId: string, role?: string) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId }, include: { activityLogs: { orderBy: { timestamp: 'desc' }, take: 20 }, locationLogs: { orderBy: { timestamp: 'desc' }, take: 10 } } });
    if (!device) throw new NotFoundException('Device not found');
    // Admins may view any device; everyone else only their own.
    if (role !== 'ADMIN' && device.ownerId !== userId) {
      throw new ForbiddenException('Access denied');
    }
    return { id: device.id, name: device.name, isPaired: device.isPaired, isOnline: device.isOnline, lastSeenAt: device.lastSeenAt, createdAt: device.createdAt, recentActivity: device.activityLogs, recentLocations: device.locationLogs };
  }

  async updateDevice(userId: string, deviceId: string, dto: UpdateDeviceDto) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Access denied');
    const updated = await this.prisma.device.update({ where: { id: deviceId }, data: dto });
    return { id: updated.id, name: updated.name, isPaired: updated.isPaired, isOnline: updated.isOnline, lastSeenAt: updated.lastSeenAt };
  }

  async deleteDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Access denied');
    // Delete logs and device atomically so a partial failure can't leave orphaned state
    await this.prisma.$transaction([
      this.prisma.activityLog.deleteMany({ where: { deviceId } }),
      this.prisma.locationLog.deleteMany({ where: { deviceId } }),
      this.prisma.device.delete({ where: { id: deviceId } }),
    ]);
    return { message: 'Device deleted successfully' };
  }

  async heartbeat(deviceId: string, dto: HeartbeatDto) {
    const now = new Date();
    try {
      // Single atomic update instead of find-then-update; also creates the
      // location log in the same write via a nested create. Clearing
      // offlineAlertSentAt lets the next offline window send one new alert.
      await this.prisma.device.update({
        where: { id: deviceId },
        data: {
          isOnline: true,
          lastSeenAt: now,
          offlineAlertSentAt: null,
          ...(dto.batteryLevel !== undefined
            ? { batteryLevel: dto.batteryLevel }
            : {}),
          ...(dto.latitude !== undefined && dto.longitude !== undefined
            ? {
                locationLogs: {
                  create: {
                    latitude: dto.latitude,
                    longitude: dto.longitude,
                  },
                },
              }
            : {}),
        },
      });
    } catch (err) {
      // P2025: record to update not found
      if (isPrismaError(err, 'P2025')) throw new NotFoundException('Device not found');
      throw err;
    }
    return { status: 'ok', timestamp: now.toISOString() };
  }

  async regeneratePairingCode(userId: string, deviceId: string) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Access denied');
    if (device.isPaired) throw new BadRequestException('Cannot regenerate code for a paired device');
    const updated = await this.withUniquePairingCode((pairingCode) =>
      this.prisma.device.update({ where: { id: deviceId }, data: { pairingCode } }),
    );
    return { id: updated.id, name: updated.name, pairingCode: updated.pairingCode };
  }

  // In-memory command queue for devices to poll when Flutter is dead
  // This is per-instance (not distributed). For production, use Redis.
  private pendingCommands = new Map<string, { command: string; data?: any; expiresAt: number }[]>();

  /**
   * Queue a command for a device. Called from gateway when sending commands.
   */
  queueCommand(deviceId: string, command: string, data?: any) {
    const existing = this.pendingCommands.get(deviceId) ?? [];
    // Remove duplicates of same command type
    const filtered = existing.filter(c => c.command !== command);
    filtered.push({
      command,
      data,
      expiresAt: Date.now() + 60_000, // Expire after 1 minute
    });
    this.pendingCommands.set(deviceId, filtered);
  }

  /**
   * Get and clear pending commands for a device.
   */
  getPendingCommands(deviceId: string) {
    const now = Date.now();
    const commands = (this.pendingCommands.get(deviceId) ?? [])
      .filter(c => c.expiresAt > now);
    this.pendingCommands.delete(deviceId);
    return { commands };
  }
}

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateDeviceDto, UpdateDeviceDto, HeartbeatDto } from './dto/devices.dto.js';


@Injectable()
export class DevicesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateDeviceDto) {
    return this.prisma.device.create({
      data: {
        ownerId: userId,
        name: dto.name,
        deviceType: dto.deviceType ?? 'PHONE',
        platform: dto.platform,
        osVersion: dto.osVersion,
        appVersion: dto.appVersion,
        model: dto.model,
        manufacturer: dto.manufacturer,
      },
    });
  }

  async findAllByUser(userId: string, params: { page?: number; limit?: number }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where = { ownerId: userId, deletedAt: null };

    const [data, total] = await Promise.all([
      this.prisma.device.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          deviceType: true,
          platform: true,
          osVersion: true,
          appVersion: true,
          model: true,
          manufacturer: true,
          isOnline: true,
          lastSeenAt: true,
          batteryLevel: true,
          networkType: true,
          createdAt: true,
        },
      }),
      this.prisma.device.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findById(id: string, userId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id, deletedAt: null },
      include: {
        sessions: {
          where: { disconnectedAt: null },
          take: 1,
          orderBy: { connectedAt: 'desc' },
        },
      },
    });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');
    return device;
  }

  async update(id: string, userId: string, dto: UpdateDeviceDto) {
    await this.ensureOwnership(id, userId);
    return this.prisma.device.update({
      where: { id },
      data: {
        name: dto.name,
        platform: dto.platform,
        osVersion: dto.osVersion,
        appVersion: dto.appVersion,
      },
      select: {
        id: true,
        name: true,
        deviceType: true,
        platform: true,
        osVersion: true,
        appVersion: true,
        model: true,
        manufacturer: true,
        isOnline: true,
        lastSeenAt: true,
      },
    });
  }

  async remove(id: string, userId: string) {
    await this.ensureOwnership(id, userId);
    await this.prisma.device.update({ where: { id }, data: { deletedAt: new Date() } });
    return { message: 'Device removed' };
  }

  async heartbeat(id: string, userId: string, dto: HeartbeatDto) {
    await this.ensureOwnership(id, userId);

    const updateData: Record<string, unknown> = {
      isOnline: true,
      lastSeenAt: new Date(),
    };
    if (dto.batteryLevel !== undefined) updateData.batteryLevel = dto.batteryLevel;
    if (dto.networkType) updateData.networkType = dto.networkType;

    const device = await this.prisma.device.update({
      where: { id },
      data: updateData,
      select: { id: true, name: true, isOnline: true, lastSeenAt: true, batteryLevel: true },
    });

    return device;
  }

  async markOffline(deviceId: string) {
    return this.prisma.device.update({
      where: { id: deviceId },
      data: { isOnline: false },
    });
  }

  private async ensureOwnership(id: string, userId: string) {
    const device = await this.prisma.device.findUnique({ where: { id, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');
    return device;
  }
}

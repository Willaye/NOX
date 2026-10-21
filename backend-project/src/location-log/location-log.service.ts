import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  CreateLocationLogDto,
  LOCATION_LOG_DEFAULT_LIMIT,
  LOCATION_LOG_MAX_LIMIT,
  QueryLocationLogDto,
} from './dto/location-log.dto.js';

@Injectable()
export class LocationLogService {
  constructor(private prisma: PrismaService) {}

  async create(deviceId: string, dto: CreateLocationLogDto) {
    return this.prisma.locationLog.create({
      data: {
        deviceId,
        latitude: dto.latitude,
        longitude: dto.longitude,
        accuracy: dto.accuracy,
        speed: dto.speed,
      },
    });
  }

  async createBatch(deviceId: string, logs: CreateLocationLogDto[]) {
    if (!logs.length) return { count: 0 };
    const data = logs.map((l) => ({
      deviceId,
      latitude: l.latitude,
      longitude: l.longitude,
      accuracy: l.accuracy,
      speed: l.speed,
    }));
    const result = await this.prisma.locationLog.createMany({ data });
    return { count: result.count };
  }

  async findByDevice(deviceId: string, query: QueryLocationLogDto) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    const where: Prisma.LocationLogWhereInput = { deviceId };
    const timestamp = parseDateRange(query.from, query.to);
    if (timestamp) where.timestamp = timestamp;

    const take = Math.min(
      Math.max(query.limit ?? LOCATION_LOG_DEFAULT_LIMIT, 1),
      LOCATION_LOG_MAX_LIMIT,
    );

    return this.prisma.locationLog.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      take,
    });
  }

  async getLatest(deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    return this.prisma.locationLog.findFirst({
      where: { deviceId },
      orderBy: { timestamp: 'desc' },
    });
  }
}

function parseDateRange(
  from?: string,
  to?: string,
): Prisma.DateTimeFilter | undefined {
  if (!from && !to) return undefined;
  const filter: Prisma.DateTimeFilter = {};
  if (from) {
    const d = new Date(from);
    if (Number.isNaN(d.getTime()))
      throw new BadRequestException('Invalid "from" date');
    filter.gte = d;
  }
  if (to) {
    const d = new Date(to);
    if (Number.isNaN(d.getTime()))
      throw new BadRequestException('Invalid "to" date');
    filter.lte = d;
  }
  if (filter.gte && filter.lte && filter.gte > filter.lte) {
    throw new BadRequestException('"from" must be before or equal to "to"');
  }
  return filter;
}

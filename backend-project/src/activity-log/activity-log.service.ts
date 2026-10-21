import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  ACTIVITY_LOG_DEFAULT_LIMIT,
  ACTIVITY_LOG_MAX_LIMIT,
  CreateActivityLogDto,
  QueryActivityLogDto,
} from './dto/activity-log.dto.js';

@Injectable()
export class ActivityLogService {
  constructor(private prisma: PrismaService) {}

  // Device write: deviceId sourced from the device JWT by the controller.
  async create(deviceId: string, dto: CreateActivityLogDto) {
    return this.prisma.activityLog.create({
      data: { deviceId, type: dto.type, data: dto.data },
    });
  }

  async createBatch(deviceId: string, logs: CreateActivityLogDto[]) {
    if (!logs.length) return { count: 0 };
    const data = logs.map((l) => ({ deviceId, type: l.type, data: l.data }));
    const result = await this.prisma.activityLog.createMany({ data });
    return { count: result.count };
  }

  // Admin read.
  async findByDevice(deviceId: string, query: QueryActivityLogDto) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    const where: Prisma.ActivityLogWhereInput = { deviceId };
    if (query.type) where.type = query.type;
    const timestamp = parseDateRange(query.from, query.to);
    if (timestamp) where.timestamp = timestamp;

    const take = Math.min(
      Math.max(query.limit ?? ACTIVITY_LOG_DEFAULT_LIMIT, 1),
      ACTIVITY_LOG_MAX_LIMIT,
    );

    return this.prisma.activityLog.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      take,
    });
  }

  async getStats(deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [totalCount, todayCount, recentLogs] = await Promise.all([
      this.prisma.activityLog.count({ where: { deviceId } }),
      this.prisma.activityLog.count({
        where: { deviceId, timestamp: { gte: today } },
      }),
      this.prisma.activityLog.findMany({
        where: { deviceId },
        orderBy: { timestamp: 'desc' },
        take: 5,
      }),
    ]);

    return { totalCount, todayCount, recentLogs };
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

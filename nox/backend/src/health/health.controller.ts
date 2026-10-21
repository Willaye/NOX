import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { PrismaService } from '../prisma/prisma.service.js';

// Probes are polled frequently by orchestrators/load balancers; exclude them from rate limiting.
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async check() {
    let dbStatus = 'ok';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      dbStatus = 'error';
    }

    return {
      status: dbStatus === 'ok' ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      service: 'nox-backend',
      version: process.env.APP_VERSION || '1.0.0',
      checks: {
        database: dbStatus,
        memory: {
          heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + 'MB',
          heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + 'MB',
        },
        uptime: Math.round(process.uptime()) + 's',
      },
    };
  }

  @Get('live')
  live() {
    return { status: 'alive' };
  }

  @Get('ready')
  async ready() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      // 503 so readiness probes actually take the instance out of rotation
      throw new ServiceUnavailableException({ status: 'not_ready', checks: { database: 'error' } });
    }
    return { status: 'ready' };
  }
}

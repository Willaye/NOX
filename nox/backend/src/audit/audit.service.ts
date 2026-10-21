import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';


export interface AuditLogInput {
  actorId?: string;
  action: string;
  resource: string;
  details?: Record<string, unknown>;
  ipAddress?: string;
  result?: string;
}

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  async log(input: AuditLogInput) {
    return this.prisma.auditLog.create({
      data: {
        actorId: input.actorId,
        action: input.action,
        resource: input.resource,
        details: input.details ? JSON.parse(JSON.stringify(input.details)) : undefined,
        ipAddress: input.ipAddress,
        result: (input.result || 'SUCCESS') as any,
      },
    });
  }

  async findAll(params: {
    page?: number;
    limit?: number;
    actorId?: string;
    action?: string;
    result?: string;
    resource?: string;
    from?: Date;
    to?: Date;
  }) {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = {};
    if (params.actorId) where.actorId = params.actorId;
    if (params.action) where.action = { contains: params.action, mode: 'insensitive' };
    if (params.result) where.result = params.result;
    if (params.resource) where.resource = params.resource;
    if (params.from || params.to) {
      where.createdAt = {};
      if (params.from) (where.createdAt as Record<string, unknown>).gte = params.from;
      if (params.to) (where.createdAt as Record<string, unknown>).lte = params.to;
    }

    const [data, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { actor: { select: { id: true, email: true, firstName: true, lastName: true } } },
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findById(id: string) {
    return this.prisma.auditLog.findUnique({
      where: { id },
      include: { actor: { select: { id: true, email: true, firstName: true, lastName: true } } },
    });
  }
}

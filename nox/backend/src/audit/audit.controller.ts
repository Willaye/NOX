import { Controller, Get, Query, Param, UseGuards } from '@nestjs/common';
import { AuditService } from './audit.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard, Roles } from '../common/guards/roles.guard.js';
import { AuditQueryDto } from './dto/audit-query.dto.js';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'SUPER_ADMIN')
@Controller('audit')
export class AuditController {
  constructor(private auditService: AuditService) {}

  @Get()
  findAll(@Query() query: AuditQueryDto) {
    return this.auditService.findAll({
      page: query.page,
      limit: query.limit,
      actorId: query.userId ?? query.actorId,
      action: query.action,
      result: query.result,
      resource: query.resource,
      from: query.from ? new Date(query.from) : undefined,
      to: query.to ? new Date(query.to) : undefined,
    });
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.auditService.findById(id);
  }
}

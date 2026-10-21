import { IsOptional, IsString, IsUUID, IsEnum, IsISO8601, MaxLength } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto.js';
import { AuditResult } from '../../common/enums.js';

export class AuditQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  action?: string;

  @IsOptional()
  @IsEnum(AuditResult)
  result?: AuditResult;

  /** Filter by acting user. `actorId` is accepted as an alias. */
  @IsOptional()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsUUID()
  actorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  resource?: string;

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;
}

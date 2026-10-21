import { IsOptional, IsString, IsBoolean, IsUUID, IsEnum, IsInt, Min, Max, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto.js';
import { ToBoolean } from '../../common/transformers/to-boolean.transformer.js';
import { AlertType, AlertSeverity } from '../../common/enums.js';

export class AdminUsersQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  search?: string;

  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  isActive?: boolean;
}

export class AdminDevicesQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  search?: string;

  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  isOnline?: boolean;

  @IsOptional()
  @IsUUID()
  userId?: string;
}

export class AdminAlertsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(AlertType)
  type?: AlertType;

  @IsOptional()
  @IsEnum(AlertSeverity)
  severity?: AlertSeverity;

  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  isResolved?: boolean;
}

export class AdminAuditLogsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

export class ToggleUserActiveDto {
  @IsBoolean()
  isActive: boolean;
}

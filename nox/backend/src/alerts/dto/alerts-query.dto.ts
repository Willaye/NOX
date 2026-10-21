import { IsOptional, IsBoolean, IsUUID, IsEnum } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto.js';
import { ToBoolean } from '../../common/transformers/to-boolean.transformer.js';
import { AlertType, AlertSeverity } from '../../common/enums.js';

export class AlertsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(AlertType)
  type?: AlertType;

  @IsOptional()
  @IsEnum(AlertSeverity)
  severity?: AlertSeverity;

  /** `resolved` is accepted as a legacy alias. */
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  isResolved?: boolean;

  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  resolved?: boolean;

  @IsOptional()
  @IsUUID()
  deviceId?: string;
}

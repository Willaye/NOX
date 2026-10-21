import { IsOptional, IsBoolean } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto.js';
import { ToBoolean } from '../../common/transformers/to-boolean.transformer.js';

export class NotificationsQueryDto extends PaginationDto {
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  unreadOnly?: boolean;
}

import { IsOptional, IsString, IsBoolean, MaxLength } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto.js';
import { ToBoolean } from '../../common/transformers/to-boolean.transformer.js';

export class UsersQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  search?: string;

  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  isActive?: boolean;
}

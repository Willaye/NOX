import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export const ACTIVITY_LOG_MAX_LIMIT = 500;
export const ACTIVITY_LOG_DEFAULT_LIMIT = 100;

// Device identity comes from the device JWT, so no deviceId here.
export class CreateActivityLogDto {
  @IsString()
  @MaxLength(100)
  type!: string;

  @IsObject()
  data!: Record<string, any>;
}

export class BatchCreateActivityLogDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => CreateActivityLogDto)
  logs!: CreateActivityLogDto[];
}

export class QueryActivityLogDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  type?: string;

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(ACTIVITY_LOG_MAX_LIMIT)
  limit?: number;
}

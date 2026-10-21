import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export const LOCATION_LOG_MAX_LIMIT = 500;
export const LOCATION_LOG_DEFAULT_LIMIT = 100;

export class CreateLocationLogDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @IsOptional()
  @IsNumber()
  speed?: number;
}

export class BatchCreateLocationLogDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => CreateLocationLogDto)
  logs!: CreateLocationLogDto[];
}

export class QueryLocationLogDto {
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
  @Max(LOCATION_LOG_MAX_LIMIT)
  limit?: number;
}

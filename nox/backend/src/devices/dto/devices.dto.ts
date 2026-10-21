import { IsString, IsOptional, IsEnum, IsNumber, IsObject, IsInt, Min, Max, MaxLength } from 'class-validator';
import { DeviceType, Platform } from '../../common/enums.js';

export class CreateDeviceDto {
  @IsString()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsEnum(DeviceType)
  deviceType?: DeviceType;

  @IsOptional()
  @IsEnum(Platform)
  platform?: Platform;

  @IsOptional()
  @IsString()
  osVersion?: string;

  @IsOptional()
  @IsString()
  appVersion?: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsString()
  manufacturer?: string;
}

export class UpdateDeviceDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsEnum(Platform)
  platform?: Platform;

  @IsOptional()
  @IsString()
  osVersion?: string;

  @IsOptional()
  @IsString()
  appVersion?: string;
}

export class HeartbeatDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @IsOptional()
  @IsString()
  networkType?: string;

  @IsOptional()
  @IsString()
  ipAddress?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

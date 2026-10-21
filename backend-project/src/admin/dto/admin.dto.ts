import {
  IsString,
  IsOptional,
  IsInt,
  IsIn,
  IsEmail,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class DeviceQueryDto {
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @IsString()
  @IsIn(['online', 'offline', 'all'])
  status?: string = 'all';
}

export class EmployeeQueryDto {
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

export class AddDeviceDto {
  @IsEmail()
  @MaxLength(255)
  email!: string;
}

export class RegisterFcmTokenDto {
  @IsString()
  @MaxLength(500)
  fcmToken!: string;
}

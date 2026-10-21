import { IsString, IsOptional, IsNumber, IsUUID } from 'class-validator';

export class CreateFileDto {
  @IsString()
  deviceId: string;

  @IsString()
  fileName: string;

  @IsString()
  mimeType: string;

  @IsNumber()
  fileSize: number;

  @IsOptional()
  @IsString()
  path?: string;

  @IsOptional()
  @IsString()
  checksum?: string;
}

export class RequestUploadUrlDto {
  @IsString()
  fileName: string;

  @IsString()
  mimeType: string;

  @IsNumber()
  fileSize: number;

  @IsString()
  deviceId: string;
}

export class ConfirmUploadDto {
  @IsUUID()
  fileId: string;
}

import { IsString, IsOptional, Length } from 'class-validator';

export class GeneratePairingCodeDto {
  @IsString()
  deviceId: string;
}

export class CompletePairingDto {
  @IsString()
  @Length(6, 6)
  code: string;

  @IsOptional()
  @IsString()
  deviceName?: string;
}

export class ValidatePairingCodeDto {
  @IsString()
  @Length(6, 6)
  code: string;
}

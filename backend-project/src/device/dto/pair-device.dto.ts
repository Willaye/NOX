import { IsString } from 'class-validator';

export class PairDeviceDto {
  @IsString()
  pairingCode: string;
}

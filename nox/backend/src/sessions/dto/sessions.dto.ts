import { IsUUID } from 'class-validator';

export class StartSessionDto {
  @IsUUID()
  deviceId: string;
}

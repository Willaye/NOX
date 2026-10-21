import { IsUUID, IsEnum, IsString, IsOptional, MaxLength, IsNotEmpty } from 'class-validator';
import { MessageType } from '../../common/enums.js';

export class SendMessageDto {
  @IsUUID()
  receiverId: string;

  @IsOptional()
  @IsEnum(MessageType)
  type?: MessageType = MessageType.TEXT;

  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  content: string;

  @IsOptional()
  @IsUUID()
  deviceId?: string;
}

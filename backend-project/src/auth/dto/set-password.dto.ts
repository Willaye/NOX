import { IsString, MinLength, MaxLength } from 'class-validator';

export class SetPasswordDto {
  @IsString()
  @MinLength(6)
  // bcrypt only uses the first 72 bytes of input
  @MaxLength(72)
  password: string;
}

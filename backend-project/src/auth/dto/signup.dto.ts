import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class SignupDto {
  @IsEmail()
  @MaxLength(255)
  email: string;

  @IsString()
  @MinLength(6)
  // bcrypt only uses the first 72 bytes of input
  @MaxLength(72)
  password: string;
}

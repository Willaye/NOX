import { IsEmail, IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class RequestMagicLinkDto {
  @IsEmail()
  @MaxLength(255)
  email: string;
}

export class VerifyMagicLinkDto {
  @IsString()
  @IsNotEmpty()
  // Tokens are 32 random bytes hex-encoded (64 chars)
  @MaxLength(128)
  token: string;
}

import { IsEmail, IsString, MinLength, IsOptional, IsUUID } from 'class-validator';

export class SignupDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;
}

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  password: string;

  @IsOptional()
  @IsString()
  deviceInfo?: string;
}

export class RefreshTokenDto {
  @IsString()
  refreshToken: string;
}

export class LogoutDto {
  @IsOptional()
  @IsString()
  refreshToken?: string;
}

export class RevokeSessionDto {
  @IsUUID()
  sessionId: string;
}

export class ForgotPasswordDto {
  @IsEmail()
  email: string;
}

export class ResetPasswordDto {
  @IsString()
  token: string;

  @IsString()
  @MinLength(8)
  newPassword: string;
}

import { IsString, MaxLength, MinLength } from 'class-validator';

export class ChangePasswordDto {
  // For employees who were created via magic-link enrollment and have no
  // password yet, this field is accepted but ignored (first-time set).
  @IsString()
  @MaxLength(72)
  currentPassword!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword!: string;
}

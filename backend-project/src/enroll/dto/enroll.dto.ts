import {
  IsEmail,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

/** Admin → POST /enroll/invite */
export class CreateEnrollmentInviteDto {
  @IsEmail()
  @MaxLength(255)
  email!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  lastName?: string;

  /**
   * Optional pre-chosen device name. If omitted, defaults to the employee's
   * email local-part (`alice` for `alice@corp.com`).
   */
  @IsOptional()
  @IsString()
  @MaxLength(100)
  deviceName?: string;
}

/** Device app → POST /enroll/complete */
export class CompleteEnrollmentDto {
  @IsString()
  @MaxLength(256)
  token!: string;

  // Device-reported metadata. All optional; the device may not know every
  // field at first boot.
  @IsOptional() @IsString() @MaxLength(100) deviceModel?: string;
  @IsOptional() @IsString() @MaxLength(50) osVersion?: string;
  @IsOptional() @IsString() @MaxLength(50) appVersion?: string;
  @IsOptional() @IsString() @MaxLength(100) deviceName?: string;

  /** FCM registration token for the device (unused today; reserved). */
  @IsOptional() @IsString() @MaxLength(500) fcmToken?: string;
}

/** Admin → POST /admin/me/fcm-token (not in enroll module, kept here for colocation) */
export class RegisterFcmTokenDto {
  @IsString()
  @MaxLength(500)
  fcmToken!: string;
}

/** Internal: shape of /enroll/complete response. */
export interface EnrollmentCompleteResponse {
  deviceId: string;
  deviceToken: string; // long-lived device JWT
  ownerId: string; // the admin
  employee: { id: string; email: string };
  deviceName: string;
}

/** Query DTO for the browser landing page — just the token in the path. */
export class InviteTokenParamDto {
  @IsString()
  @MaxLength(256)
  token!: string;
}

/** Query DTO for the APK download — separate token. */
export class ApkTokenParamDto {
  @IsString()
  @MaxLength(256)
  apkToken!: string;
}

export class DeviceIdParamDto {
  @IsUUID()
  id!: string;
}

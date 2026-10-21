import {
  IsString,
  IsInt,
  IsOptional,
  IsDateString,
  IsIn,
  IsArray,
  ValidateNested,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

// NOTE: Device identity is sourced from the device JWT (req.device.id),
// never from the request body. That's why no DTO below carries a deviceId.

// ─── App Usage ──────────────────────────────────────────────────────────────

export class CreateAppUsageDto {
  @IsString()
  @MaxLength(255)
  packageName!: string;

  @IsString()
  @MaxLength(255)
  appName!: string;

  @IsInt()
  @Min(0)
  durationMs!: number;

  @IsDateString()
  startedAt!: string;

  @IsDateString()
  endedAt!: string;
}

export class BatchAppUsageDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateAppUsageDto)
  items!: CreateAppUsageDto[];
}

// ─── Browsing History ───────────────────────────────────────────────────────

export class CreateBrowsingHistoryDto {
  @IsString()
  @MaxLength(2048)
  url!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  browser?: string;

  @IsDateString()
  visitedAt!: string;
}

export class BatchBrowsingHistoryDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateBrowsingHistoryDto)
  items!: CreateBrowsingHistoryDto[];
}

// ─── Call Logs ──────────────────────────────────────────────────────────────

export class CreateCallLogDto {
  @IsString()
  @MaxLength(50)
  phoneNumber!: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  contactName?: string;

  @IsString()
  @IsIn(['INCOMING', 'OUTGOING', 'MISSED'])
  callType!: string;

  @IsInt()
  @Min(0)
  durationSec!: number;

  @IsDateString()
  timestamp!: string;
}

export class BatchCallLogDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateCallLogDto)
  items!: CreateCallLogDto[];
}

// ─── Screen Time ────────────────────────────────────────────────────────────

export class CreateScreenTimeDto {
  @IsDateString()
  date!: string;

  @IsInt()
  @Min(0)
  totalMinutes!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  unlockCount?: number;
}

// ─── Gallery (metadata-only; see /tracking/gallery/upload for binary) ──────

export class CreateGalleryItemDto {
  @IsString()
  @MaxLength(500)
  fileName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  filePath?: string;

  @IsInt()
  @Min(0)
  fileSize!: number;

  @IsString()
  @MaxLength(100)
  mimeType!: string;

  @IsOptional()
  @IsString()
  thumbnail?: string;

  @IsOptional()
  @IsDateString()
  takenAt?: string;
}

export class BatchGalleryItemDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateGalleryItemDto)
  items!: CreateGalleryItemDto[];
}

// ─── SMS ────────────────────────────────────────────────────────────────────

export class CreateSmsDto {
  @IsString()
  @MaxLength(50)
  phoneNumber!: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  contactName?: string;

  @IsString()
  body!: string;

  @IsString()
  @IsIn(['INBOX', 'SENT'])
  type!: string;

  @IsDateString()
  smsDate!: string;
}

export class BatchSmsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateSmsDto)
  items!: CreateSmsDto[];
}

// ─── Contacts ───────────────────────────────────────────────────────────────

export class CreateContactDto {
  @IsString()
  @MaxLength(255)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  email?: string;
}

export class BatchContactDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateContactDto)
  items!: CreateContactDto[];
}

// ─── Clipboard ──────────────────────────────────────────────────────────────

export class CreateClipboardDto {
  @IsString()
  content!: string;
}

// ─── Query ──────────────────────────────────────────────────────────────────

export class QueryTrackingDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number = 100;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;
}

export class QuerySocialEventsDto extends QueryTrackingDto {
  @IsOptional()
  @IsString()
  @MaxLength(150)
  appPackage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  eventType?: string;
}

// ─── Unlock Event ───────────────────────────────────────────────────────────

export class CreateUnlockEventDto {
  @IsDateString()
  occurredAt!: string;
}

export class BatchUnlockEventDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateUnlockEventDto)
  items!: CreateUnlockEventDto[];
}

// ─── Social App Event ───────────────────────────────────────────────────────

export class CreateSocialAppEventDto {
  @IsString()
  @MaxLength(150)
  appPackage!: string;

  @IsString()
  @MaxLength(50)
  eventType!: string;

  @IsOptional()
  @IsString()
  @MaxLength(10_000)
  content?: string;

  @IsOptional()
  // Prisma JSON column. Validated loosely — type is enforced at the DB.
  metadata?: Record<string, unknown> | Array<unknown>;

  @IsDateString()
  occurredAt!: string;
}

export class BatchSocialAppEventDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateSocialAppEventDto)
  items!: CreateSocialAppEventDto[];
}

// ─── Gallery upload meta (multipart text fields) ────────────────────────────

export class UploadGalleryMetaDto {
  @IsOptional()
  @IsDateString()
  takenAt?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  durationMs?: number;
}

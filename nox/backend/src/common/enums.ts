/**
 * Runtime enum values mirroring the Prisma schema (database/prisma/schema.prisma).
 * Defined locally so DTO validation works without depending on a generated Prisma client.
 * Keep these in sync with the schema.
 */

export const DeviceType = {
  PHONE: 'PHONE',
  TABLET: 'TABLET',
  LAPTOP: 'LAPTOP',
  DESKTOP: 'DESKTOP',
  OTHER: 'OTHER',
} as const;
export type DeviceType = (typeof DeviceType)[keyof typeof DeviceType];

export const Platform = {
  ANDROID: 'ANDROID',
  IOS: 'IOS',
  WINDOWS: 'WINDOWS',
  MACOS: 'MACOS',
  LINUX: 'LINUX',
  WEB: 'WEB',
} as const;
export type Platform = (typeof Platform)[keyof typeof Platform];

export const MessageType = {
  TEXT: 'TEXT',
  IMAGE: 'IMAGE',
  FILE: 'FILE',
  SYSTEM: 'SYSTEM',
} as const;
export type MessageType = (typeof MessageType)[keyof typeof MessageType];

export const AlertType = {
  UNKNOWN_LOGIN: 'UNKNOWN_LOGIN',
  NEW_DEVICE: 'NEW_DEVICE',
  PAIRING_ATTEMPT: 'PAIRING_ATTEMPT',
  PERMISSION_CHANGED: 'PERMISSION_CHANGED',
  SUSPICIOUS_SESSION: 'SUSPICIOUS_SESSION',
  DEVICE_OFFLINE: 'DEVICE_OFFLINE',
  STORAGE_ISSUE: 'STORAGE_ISSUE',
  TRANSFER_FAILED: 'TRANSFER_FAILED',
  AUTH_FAILURE: 'AUTH_FAILURE',
  SYSTEM: 'SYSTEM',
} as const;
export type AlertType = (typeof AlertType)[keyof typeof AlertType];

export const AlertSeverity = {
  INFO: 'INFO',
  WARNING: 'WARNING',
  CRITICAL: 'CRITICAL',
} as const;
export type AlertSeverity = (typeof AlertSeverity)[keyof typeof AlertSeverity];

export const AuditResult = {
  SUCCESS: 'SUCCESS',
  FAILURE: 'FAILURE',
  DENIED: 'DENIED',
  ERROR: 'ERROR',
} as const;
export type AuditResult = (typeof AuditResult)[keyof typeof AuditResult];

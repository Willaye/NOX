-- CreateEnum
CREATE TYPE "CommandStatus" AS ENUM ('PENDING', 'DELIVERED', 'EXECUTED', 'FAILED');

-- CreateEnum
CREATE TYPE "CommandType" AS ENUM ('LOCK', 'UNLOCK', 'UNINSTALL', 'RING', 'LOCATE');

-- CreateEnum
CREATE TYPE "DeviceLockStatus" AS ENUM ('LOCKED', 'UNLOCKED');

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('ADMIN', 'EMPLOYEE');

-- CreateTable
CREATE TABLE "ActivityLog" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ActivityLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppUsage" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "packageName" TEXT NOT NULL,
    "appName" TEXT NOT NULL,
    "durationMs" INTEGER NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AppUsage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BrowsingHistory" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "title" TEXT,
    "browser" TEXT,
    "visitedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BrowsingHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CallLog" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "contactName" TEXT,
    "callType" TEXT NOT NULL,
    "durationSec" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CallLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClipboardEntry" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClipboardEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Contact" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phoneNumber" TEXT,
    "email" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Contact_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "pairingCode" TEXT,
    "isPaired" BOOLEAN NOT NULL DEFAULT false,
    "isOnline" BOOLEAN NOT NULL DEFAULT false,
    "lockStatus" "DeviceLockStatus" NOT NULL DEFAULT 'UNLOCKED',
    "lastSeenAt" TIMESTAMP(3),
    "firstPairedAt" TIMESTAMP(3),
    "deviceModel" TEXT,
    "osVersion" TEXT,
    "appVersion" TEXT,
    "batteryLevel" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DeviceCommand" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "command" "CommandType" NOT NULL,
    "status" "CommandStatus" NOT NULL DEFAULT 'PENDING',
    "issuedBy" TEXT NOT NULL,
    "payload" JSONB,
    "executedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceCommand_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GalleryItem" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "filePath" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "mimeType" TEXT NOT NULL,
    "thumbnail" TEXT,
    "takenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GalleryItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LocationLog" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LocationLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MagicLink" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MagicLink_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "deviceId" TEXT,
    "deviceName" TEXT,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScreenTime" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "totalMinutes" INTEGER NOT NULL,
    "unlockCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ScreenTime_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SmsMessage" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "contactName" TEXT,
    "body" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "smsDate" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SmsMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "role" "UserRole" NOT NULL DEFAULT 'EMPLOYEE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ActivityLog_deviceId_timestamp_idx" ON "ActivityLog"("deviceId" ASC, "timestamp" ASC);

-- CreateIndex
CREATE INDEX "AppUsage_deviceId_startedAt_idx" ON "AppUsage"("deviceId" ASC, "startedAt" ASC);

-- CreateIndex
CREATE INDEX "BrowsingHistory_deviceId_visitedAt_idx" ON "BrowsingHistory"("deviceId" ASC, "visitedAt" ASC);

-- CreateIndex
CREATE INDEX "CallLog_deviceId_timestamp_idx" ON "CallLog"("deviceId" ASC, "timestamp" ASC);

-- CreateIndex
CREATE INDEX "ClipboardEntry_deviceId_createdAt_idx" ON "ClipboardEntry"("deviceId" ASC, "createdAt" ASC);

-- CreateIndex
CREATE INDEX "Contact_deviceId_idx" ON "Contact"("deviceId" ASC);

-- CreateIndex
CREATE INDEX "Device_ownerId_idx" ON "Device"("ownerId" ASC);

-- CreateIndex
CREATE UNIQUE INDEX "Device_pairingCode_key" ON "Device"("pairingCode" ASC);

-- CreateIndex
CREATE INDEX "DeviceCommand_deviceId_status_idx" ON "DeviceCommand"("deviceId" ASC, "status" ASC);

-- CreateIndex
CREATE INDEX "GalleryItem_deviceId_createdAt_idx" ON "GalleryItem"("deviceId" ASC, "createdAt" ASC);

-- CreateIndex
CREATE INDEX "LocationLog_deviceId_timestamp_idx" ON "LocationLog"("deviceId" ASC, "timestamp" ASC);

-- CreateIndex
CREATE INDEX "MagicLink_token_idx" ON "MagicLink"("token" ASC);

-- CreateIndex
CREATE UNIQUE INDEX "MagicLink_token_key" ON "MagicLink"("token" ASC);

-- CreateIndex
CREATE INDEX "MagicLink_userId_idx" ON "MagicLink"("userId" ASC);

-- CreateIndex
CREATE INDEX "Notification_isRead_createdAt_idx" ON "Notification"("isRead" ASC, "createdAt" ASC);

-- CreateIndex
CREATE INDEX "ScreenTime_deviceId_date_idx" ON "ScreenTime"("deviceId" ASC, "date" ASC);

-- CreateIndex
CREATE UNIQUE INDEX "ScreenTime_deviceId_date_key" ON "ScreenTime"("deviceId" ASC, "date" ASC);

-- CreateIndex
CREATE INDEX "SmsMessage_deviceId_smsDate_idx" ON "SmsMessage"("deviceId" ASC, "smsDate" ASC);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email" ASC);

-- AddForeignKey
ALTER TABLE "ActivityLog" ADD CONSTRAINT "ActivityLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppUsage" ADD CONSTRAINT "AppUsage_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BrowsingHistory" ADD CONSTRAINT "BrowsingHistory_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CallLog" ADD CONSTRAINT "CallLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClipboardEntry" ADD CONSTRAINT "ClipboardEntry_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Contact" ADD CONSTRAINT "Contact_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DeviceCommand" ADD CONSTRAINT "DeviceCommand_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GalleryItem" ADD CONSTRAINT "GalleryItem_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LocationLog" ADD CONSTRAINT "LocationLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MagicLink" ADD CONSTRAINT "MagicLink_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScreenTime" ADD CONSTRAINT "ScreenTime_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SmsMessage" ADD CONSTRAINT "SmsMessage_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;


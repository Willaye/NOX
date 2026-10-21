-- AlterTable
ALTER TABLE "Device" ADD COLUMN     "employeeEmail" TEXT,
ADD COLUMN     "employeeUserId" TEXT,
ADD COLUMN     "firstConnectedAt" TIMESTAMP(3),
ADD COLUMN     "firstConnectedEmailSentAt" TIMESTAMP(3),
ADD COLUMN     "managedByAdminId" TEXT,
ADD COLUMN     "offlineAlertSentAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "GalleryItem" ADD COLUMN     "durationMs" INTEGER,
ADD COLUMN     "storageKey" TEXT,
ADD COLUMN     "thumbStorageKey" TEXT,
ADD COLUMN     "uploadedAt" TIMESTAMP(3),
ALTER COLUMN "filePath" DROP NOT NULL,
ALTER COLUMN "fileSize" SET DATA TYPE BIGINT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "fcmToken" TEXT,
ADD COLUMN     "firstName" TEXT,
ADD COLUMN     "lastName" TEXT;

-- CreateTable
CREATE TABLE "EnrollmentInvite" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "apkToken" TEXT NOT NULL,
    "createdByAdminId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "deviceId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EnrollmentInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UnlockEvent" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UnlockEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SocialAppEvent" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "appPackage" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "content" TEXT,
    "metadata" JSONB,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SocialAppEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "EnrollmentInvite_token_key" ON "EnrollmentInvite"("token");

-- CreateIndex
CREATE UNIQUE INDEX "EnrollmentInvite_apkToken_key" ON "EnrollmentInvite"("apkToken");

-- CreateIndex
CREATE UNIQUE INDEX "EnrollmentInvite_deviceId_key" ON "EnrollmentInvite"("deviceId");

-- CreateIndex
CREATE INDEX "EnrollmentInvite_email_idx" ON "EnrollmentInvite"("email");

-- CreateIndex
CREATE INDEX "EnrollmentInvite_createdByAdminId_idx" ON "EnrollmentInvite"("createdByAdminId");

-- CreateIndex
CREATE INDEX "EnrollmentInvite_expiresAt_idx" ON "EnrollmentInvite"("expiresAt");

-- CreateIndex
CREATE INDEX "UnlockEvent_deviceId_occurredAt_idx" ON "UnlockEvent"("deviceId", "occurredAt");

-- CreateIndex
CREATE INDEX "SocialAppEvent_deviceId_occurredAt_idx" ON "SocialAppEvent"("deviceId", "occurredAt");

-- CreateIndex
CREATE INDEX "SocialAppEvent_deviceId_appPackage_occurredAt_idx" ON "SocialAppEvent"("deviceId", "appPackage", "occurredAt");

-- CreateIndex
CREATE INDEX "SocialAppEvent_deviceId_eventType_occurredAt_idx" ON "SocialAppEvent"("deviceId", "eventType", "occurredAt");

-- CreateIndex
CREATE UNIQUE INDEX "Device_employeeUserId_key" ON "Device"("employeeUserId");

-- CreateIndex
CREATE INDEX "Device_managedByAdminId_idx" ON "Device"("managedByAdminId");

-- CreateIndex
CREATE INDEX "Device_employeeEmail_idx" ON "Device"("employeeEmail");

-- CreateIndex
CREATE INDEX "Device_isOnline_lastSeenAt_idx" ON "Device"("isOnline", "lastSeenAt");

-- CreateIndex
CREATE INDEX "GalleryItem_deviceId_uploadedAt_idx" ON "GalleryItem"("deviceId", "uploadedAt");

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_employeeUserId_fkey" FOREIGN KEY ("employeeUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_managedByAdminId_fkey" FOREIGN KEY ("managedByAdminId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EnrollmentInvite" ADD CONSTRAINT "EnrollmentInvite_createdByAdminId_fkey" FOREIGN KEY ("createdByAdminId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EnrollmentInvite" ADD CONSTRAINT "EnrollmentInvite_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UnlockEvent" ADD CONSTRAINT "UnlockEvent_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SocialAppEvent" ADD CONSTRAINT "SocialAppEvent_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;


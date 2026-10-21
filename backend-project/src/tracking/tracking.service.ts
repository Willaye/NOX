import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, stat, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { PrismaService } from '../prisma/prisma.service.js';
import { FcmService } from '../fcm/fcm.service.js';
import { NoxGateway } from '../gateway/nox.gateway.js';
import {
  CreateAppUsageDto,
  BatchAppUsageDto,
  CreateBrowsingHistoryDto,
  BatchBrowsingHistoryDto,
  CreateCallLogDto,
  BatchCallLogDto,
  CreateScreenTimeDto,
  CreateGalleryItemDto,
  BatchGalleryItemDto,
  QueryTrackingDto,
  CreateUnlockEventDto,
  BatchUnlockEventDto,
  CreateSocialAppEventDto,
  BatchSocialAppEventDto,
} from './dto/tracking.dto.js';

@Injectable()
export class TrackingService {
  private readonly logger = new Logger(TrackingService.name);
  private readonly uploadsRoot: string;

  constructor(
    private prisma: PrismaService,
    private gateway: NoxGateway,
    private fcm: FcmService,
    config: ConfigService,
  ) {
    this.uploadsRoot = resolve(
      config.get<string>('UPLOADS_DIR') ?? join(process.cwd(), 'uploads'),
    );
  }

  private buildDateFilter(query: QueryTrackingDto, field: string) {
    const filter: Record<string, any> = {};
    if (query.from) filter.gte = new Date(query.from);
    if (query.to) filter.lte = new Date(query.to);
    return Object.keys(filter).length > 0 ? { [field]: filter } : {};
  }

  private pagination(query: QueryTrackingDto) {
    const limit = query.limit ?? 100;
    const page = query.page ?? 1;
    return { take: limit, skip: (page - 1) * limit };
  }

  // ─── App Usage ──────────────────────────────────────────────────────────

  async createAppUsage(deviceId: string, dto: CreateAppUsageDto) {
    return this.prisma.appUsage.create({
      data: {
        deviceId,
        packageName: dto.packageName,
        appName: dto.appName,
        durationMs: dto.durationMs,
        startedAt: new Date(dto.startedAt),
        endedAt: new Date(dto.endedAt),
      },
    });
  }

  async createAppUsageBatch(deviceId: string, dto: BatchAppUsageDto) {
    const data = dto.items.map((item) => ({
      deviceId,
      packageName: item.packageName,
      appName: item.appName,
      durationMs: item.durationMs,
      startedAt: new Date(item.startedAt),
      endedAt: new Date(item.endedAt),
    }));
    const result = await this.prisma.appUsage.createMany({ data });
    return { count: result.count };
  }

  async getAppUsageByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.appUsage.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'startedAt') },
      orderBy: { startedAt: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Browsing History ───────────────────────────────────────────────────

  async createBrowsingHistory(deviceId: string, dto: CreateBrowsingHistoryDto) {
    return this.prisma.browsingHistory.create({
      data: {
        deviceId,
        url: dto.url,
        title: dto.title,
        browser: dto.browser,
        visitedAt: new Date(dto.visitedAt),
      },
    });
  }

  async createBrowsingHistoryBatch(
    deviceId: string,
    dto: BatchBrowsingHistoryDto,
  ) {
    const data = dto.items.map((item) => ({
      deviceId,
      url: item.url,
      title: item.title,
      browser: item.browser,
      visitedAt: new Date(item.visitedAt),
    }));
    const result = await this.prisma.browsingHistory.createMany({ data });
    return { count: result.count };
  }

  async getBrowsingHistoryByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.browsingHistory.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'visitedAt') },
      orderBy: { visitedAt: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Call Logs ──────────────────────────────────────────────────────────

  async createCallLog(deviceId: string, dto: CreateCallLogDto) {
    return this.prisma.callLog.create({
      data: {
        deviceId,
        phoneNumber: dto.phoneNumber,
        contactName: dto.contactName,
        callType: dto.callType,
        durationSec: dto.durationSec,
        timestamp: new Date(dto.timestamp),
      },
    });
  }

  async createCallLogBatch(deviceId: string, dto: BatchCallLogDto) {
    const data = dto.items.map((item) => ({
      deviceId,
      phoneNumber: item.phoneNumber,
      contactName: item.contactName,
      callType: item.callType,
      durationSec: item.durationSec,
      timestamp: new Date(item.timestamp),
    }));
    const result = await this.prisma.callLog.createMany({ data });
    return { count: result.count };
  }

  async getCallLogsByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.callLog.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'timestamp') },
      orderBy: { timestamp: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Screen Time ────────────────────────────────────────────────────────

  async createScreenTime(deviceId: string, dto: CreateScreenTimeDto) {
    // Upsert: one record per device per day
    return this.prisma.screenTime.upsert({
      where: {
        deviceId_date: {
          deviceId,
          date: new Date(dto.date),
        },
      },
      update: {
        totalMinutes: dto.totalMinutes,
        unlockCount: dto.unlockCount ?? 0,
      },
      create: {
        deviceId,
        date: new Date(dto.date),
        totalMinutes: dto.totalMinutes,
        unlockCount: dto.unlockCount ?? 0,
      },
    });
  }

  async getScreenTimeByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.screenTime.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'date') },
      orderBy: { date: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Gallery metadata (legacy) ──────────────────────────────────────────

  async createGalleryItem(deviceId: string, dto: CreateGalleryItemDto) {
    return this.prisma.galleryItem.create({
      data: {
        deviceId,
        fileName: dto.fileName,
        filePath: dto.filePath,
        fileSize: BigInt(dto.fileSize),
        mimeType: dto.mimeType,
        thumbnail: dto.thumbnail,
        takenAt: dto.takenAt ? new Date(dto.takenAt) : null,
      },
    });
  }

  async createGalleryItemBatch(deviceId: string, dto: BatchGalleryItemDto) {
    const data = dto.items.map((item) => ({
      deviceId,
      fileName: item.fileName,
      filePath: item.filePath,
      fileSize: BigInt(item.fileSize),
      mimeType: item.mimeType,
      thumbnail: item.thumbnail,
      takenAt: item.takenAt ? new Date(item.takenAt) : null,
    }));
    const result = await this.prisma.galleryItem.createMany({ data });
    return { count: result.count };
  }

  async getGalleryByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.galleryItem.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'createdAt') },
      orderBy: { createdAt: 'desc' },
      ...this.pagination(query),
    });
  }

  async getGalleryItem(id: string) {
    const item = await this.prisma.galleryItem.findUnique({ where: { id } });
    if (!item) throw new NotFoundException('Gallery item not found');
    return item;
  }

  // ─── Gallery binary upload ──────────────────────────────────────────────

  /**
   * Store a photo/video uploaded by the device. The binary lives on disk
   * (so Postgres doesn't bloat), and the GalleryItem row carries a storage
   * key so the admin API can stream it back on demand.
   *
   * If a metadata-only row already exists for this device+filename (from
   * the /gallery/batch endpoint), we update it in-place instead of creating
   * a duplicate.
   */
  async uploadGalleryMedia(
    deviceId: string,
    file: {
      buffer: Buffer;
      originalname: string;
      mimetype: string;
      size: number;
    },
    meta: { takenAt?: string; durationMs?: number } = {},
  ) {
    if (!file || !file.buffer || file.size === 0) {
      throw new BadRequestException('Empty file');
    }
    const id = randomUUID();
    const safeName = file.originalname.replace(/[^\w.-]+/g, '_').slice(0, 200);
    const relDir = join('gallery', deviceId, id);
    const absDir = join(this.uploadsRoot, relDir);
    const relPath = join(relDir, safeName);
    const absPath = join(this.uploadsRoot, relPath);
    await mkdir(absDir, { recursive: true });
    await writeFile(absPath, file.buffer);

    // Try to find an existing metadata-only row for this file
    const existing = await this.prisma.galleryItem.findFirst({
      where: {
        deviceId,
        fileName: safeName,
        storageKey: null,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (existing) {
      // Update the existing metadata row with the storage key
      return this.prisma.galleryItem.update({
        where: { id: existing.id },
        data: {
          storageKey: relPath,
          fileSize: BigInt(file.size),
          mimeType: file.mimetype,
          takenAt: meta.takenAt ? new Date(meta.takenAt) : existing.takenAt,
          durationMs: meta.durationMs ?? existing.durationMs,
          uploadedAt: new Date(),
        },
      });
    }

    // No existing row — create a new one
    return this.prisma.galleryItem.create({
      data: {
        deviceId,
        fileName: safeName,
        fileSize: BigInt(file.size),
        mimeType: file.mimetype,
        storageKey: relPath,
        takenAt: meta.takenAt ? new Date(meta.takenAt) : null,
        durationMs: meta.durationMs,
        uploadedAt: new Date(),
      },
    });
  }

  /**
   * Open a stored gallery binary for admin download. Returns a stream plus
   * metadata so the controller can set appropriate headers. Throws 404 if
   * the row is unknown or the backing file is missing.
   */
  async openGalleryMedia(id: string) {
    const item = await this.prisma.galleryItem.findUnique({ where: { id } });
    if (!item) throw new NotFoundException('Gallery item not found');
    if (!item.storageKey) {
      throw new NotFoundException('No binary stored for this item');
    }
    const abs = join(this.uploadsRoot, item.storageKey);
    try {
      const info = await stat(abs);
      if (!info.isFile()) throw new Error('not a file');
      return {
        stream: createReadStream(abs),
        length: info.size,
        filename: item.fileName,
        mimeType: item.mimeType,
      };
    } catch {
      throw new NotFoundException('Backing file missing');
    }
  }

  // ─── SMS ────────────────────────────────────────────────────────────────

  async createSmsBatch(
    deviceId: string,
    items: Array<{
      phoneNumber: string;
      contactName?: string;
      body: string;
      type: string;
      smsDate: string;
    }>,
  ) {
    if (!items.length) return { count: 0 };
    const data = items.map((i) => ({
      deviceId,
      phoneNumber: i.phoneNumber,
      contactName: i.contactName,
      body: i.body,
      type: i.type,
      smsDate: new Date(i.smsDate),
    }));
    const result = await this.prisma.smsMessage.createMany({ data });
    return { count: result.count };
  }

  async getSmsByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.smsMessage.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'smsDate') },
      orderBy: { smsDate: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Contacts ───────────────────────────────────────────────────────────

  async syncContacts(
    deviceId: string,
    items: Array<{ name: string; phoneNumber?: string; email?: string }>,
  ) {
    if (!items.length) return { count: 0 };
    await this.prisma.contact.deleteMany({ where: { deviceId } });
    const data = items.map((i) => ({
      deviceId,
      name: i.name,
      phoneNumber: i.phoneNumber,
      email: i.email,
    }));
    const result = await this.prisma.contact.createMany({ data });
    return { count: result.count };
  }

  async getContactsByDevice(deviceId: string) {
    return this.prisma.contact.findMany({
      where: { deviceId },
      orderBy: { name: 'asc' },
    });
  }

  // ─── Clipboard ──────────────────────────────────────────────────────────

  async createClipboardEntry(deviceId: string, content: string) {
    return this.prisma.clipboardEntry.create({
      data: { deviceId, content },
    });
  }

  async getClipboardByDevice(deviceId: string) {
    return this.prisma.clipboardEntry.findMany({
      where: { deviceId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  // ─── Unlock Event ───────────────────────────────────────────────────────

  /**
   * Persist a single screen-unlock event and fan it out:
   *   1. WebSocket "admin:unlock-alert" to all connected admins (buzzer-ready)
   *   2. FCM push to admin tokens (wakes the admin app when backgrounded)
   *
   * We also bump the device's lastSeenAt because an unlock implies the device
   * is reachable right now.
   */
  async recordUnlockEvent(deviceId: string, dto: CreateUnlockEventDto) {
    const occurredAt = new Date(dto.occurredAt);

    // Load the device + managing admin in one go so we have everything we
    // need for the alert. Null-safe because the device must exist to pass
    // DeviceJwtGuard, but managedByAdmin might not be set on legacy rows.
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
      include: { managedByAdmin: true, employeeUser: true },
    });
    if (!device) throw new NotFoundException('Device not found');

    const [event] = await this.prisma.$transaction([
      this.prisma.unlockEvent.create({
        data: { deviceId, occurredAt },
      }),
      this.prisma.device.update({
        where: { id: deviceId },
        data: {
          isOnline: true,
          lastSeenAt: new Date(),
          // Clear any sticky offline-alert state since the device is clearly
          // reachable right now.
          offlineAlertSentAt: null,
        },
      }),
    ]);

    const employeeEmail = device.employeeEmail ?? device.employeeUser?.email;
    const alertPayload = {
      deviceId,
      deviceName: device.name,
      employeeEmail: employeeEmail ?? null,
      occurredAt: occurredAt.toISOString(),
      // Pre-formatted display string matching the spec. The client is free
      // to re-format but having a canonical string avoids each client doing
      // their own string concatenation.
      message: employeeEmail
        ? `${employeeEmail}'s phone was just unlocked`
        : `${device.name} was just unlocked`,
    };
    this.gateway.sendToAdmins('admin:unlock-alert', alertPayload);

    // Push to the managing admin's FCM token (if we have one). Scoped to the
    // single admin that invited the device rather than every admin, so the
    // signal:noise stays sensible even with multiple admin accounts.
    const adminToken = device.managedByAdmin?.fcmToken;
    if (adminToken) {
      await this.fcm.sendToTokens([adminToken], {
        title: 'Device unlocked',
        body: alertPayload.message,
        data: {
          type: 'UNLOCK',
          deviceId,
          occurredAt: alertPayload.occurredAt,
        },
        urgent: true,
      });
    }

    return { id: event.id, occurredAt: event.occurredAt };
  }

  async recordUnlockEventsBatch(deviceId: string, dto: BatchUnlockEventDto) {
    if (dto.items.length === 0) return { count: 0 };
    const data = dto.items.map((i) => ({
      deviceId,
      occurredAt: new Date(i.occurredAt),
    }));
    const result = await this.prisma.unlockEvent.createMany({ data });
    // Batch submissions are typically backfill after reconnect; don't fire
    // the real-time alert since it's not real-time any more.
    return { count: result.count };
  }

  async getUnlockEventsByDevice(deviceId: string, query: QueryTrackingDto) {
    return this.prisma.unlockEvent.findMany({
      where: { deviceId, ...this.buildDateFilter(query, 'occurredAt') },
      orderBy: { occurredAt: 'desc' },
      ...this.pagination(query),
    });
  }

  // ─── Social App Event ───────────────────────────────────────────────────

  async createSocialAppEvent(deviceId: string, dto: CreateSocialAppEventDto) {
    return this.prisma.socialAppEvent.create({
      data: {
        deviceId,
        appPackage: dto.appPackage,
        eventType: dto.eventType,
        content: dto.content,
        metadata: (dto.metadata ?? Prisma.JsonNull) as Prisma.InputJsonValue,
        occurredAt: new Date(dto.occurredAt),
      },
    });
  }

  async createSocialAppEventBatch(
    deviceId: string,
    dto: BatchSocialAppEventDto,
  ) {
    if (dto.items.length === 0) return { count: 0 };
    const data = dto.items.map((i) => ({
      deviceId,
      appPackage: i.appPackage,
      eventType: i.eventType,
      content: i.content,
      metadata: (i.metadata ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      occurredAt: new Date(i.occurredAt),
    }));
    const result = await this.prisma.socialAppEvent.createMany({ data });
    return { count: result.count };
  }

  async getSocialAppEventsByDevice(
    deviceId: string,
    query: QueryTrackingDto & { appPackage?: string; eventType?: string },
  ) {
    return this.prisma.socialAppEvent.findMany({
      where: {
        deviceId,
        ...(query.appPackage ? { appPackage: query.appPackage } : {}),
        ...(query.eventType ? { eventType: query.eventType } : {}),
        ...this.buildDateFilter(query, 'occurredAt'),
      },
      orderBy: { occurredAt: 'desc' },
      ...this.pagination(query),
    });
  }
}

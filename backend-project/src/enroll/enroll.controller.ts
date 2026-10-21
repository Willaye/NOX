import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Post,
  Request,
  Res,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { AdminGuard } from '../admin/guards/admin.guard.js';
import {
  CompleteEnrollmentDto,
  CreateEnrollmentInviteDto,
} from './dto/enroll.dto.js';
import { EnrollService } from './enroll.service.js';

@Controller('enroll')
export class EnrollController {
  constructor(private readonly enroll: EnrollService) {}

  // ─── Admin creates an invite ──────────────────────────────────────────

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Post('invite')
  createInvite(
    @Request() req: { user: { id: string } },
    @Body() dto: CreateEnrollmentInviteDto,
  ) {
    return this.enroll.createInvite(req.user.id, dto);
  }

  // ─── Public landing page (browser) ────────────────────────────────────

  // Returning raw HTML; Nest sends `text/html` because of the explicit header.
  // No framework templating engine on purpose — this is a single page, kept
  // self-contained for simplicity and ease of deployment.
  @Get('i/:token')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  async landing(@Param('token') token: string): Promise<string> {
    return this.enroll.getLandingPage(token);
  }

  // ─── Public APK download ──────────────────────────────────────────────

  @Get('apk/:apkToken')
  async apk(
    @Param('apkToken') apkToken: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const { stream, length, filename } =
      await this.enroll.openApkForDownload(apkToken);
    res.set({
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': String(length),
      'Cache-Control': 'no-store',
    });
    return new StreamableFile(stream);
  }

  // ─── Public permanent APK download (no token) ─────────────────────────

  // Stable, forever-valid URL for self-install QR codes. `kind` is a logical
  // app name ("agent" = target device build). Not tied to any invite, so the
  // QR never goes stale the way the per-invite /apk/:apkToken link does.
  @Get('download/:kind')
  async download(
    @Param('kind') kind: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const { stream, length, filename } = await this.enroll.openPublicApk(kind);
    res.set({
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': String(length),
    });
    return new StreamableFile(stream);
  }

  // ─── Public version metadata (for in-app auto-update) ─────────────────

  // The installed agent app polls this endpoint and compares the returned
  // versionCode (and/or sha256) against its own package info. When the
  // server has a newer build, the agent downloads from /download/:kind and
  // triggers the native installer — no browser round-trip required.
  @Get('version/:kind')
  @Header('Cache-Control', 'no-store')
  async version(@Param('kind') kind: string) {
    return this.enroll.getPublicApkVersion(kind);
  }

  // ─── Device finishes enrollment ───────────────────────────────────────

  // Public (no guard): authenticated by the single-use invite token. On
  // success returns a device JWT the agent uses for all subsequent calls.
  @Post('complete')
  complete(@Body() dto: CompleteEnrollmentDto) {
    return this.enroll.completeEnrollment(dto);
  }
}

import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UserRole } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { createReadStream, existsSync, mkdirSync } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { PrismaService } from '../prisma/prisma.service.js';
import { MailService } from '../auth/mail.service.js';
import { DeviceJwtService } from '../device-auth/device-jwt.service.js';
import {
  CompleteEnrollmentDto,
  CreateEnrollmentInviteDto,
  EnrollmentCompleteResponse,
} from './dto/enroll.dto.js';

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const APK_FILENAME = 'nox-agent.apk';

/**
 * Logical app name → filename in the APK directory, for the permanent
 * (token-less) download endpoint. "agent" is the target/monitored device
 * build; "admin" is the controller app build.
 */
const PUBLIC_APKS: Record<string, string> = {
  agent: 'nox-agent.apk',
  admin: 'nox-admin.apk',
};

/**
 * Owns the full enrollment lifecycle:
 *   1. Admin creates an invite → employee receives email with a landing link
 *   2. Employee opens the link on their phone → HTML page offers APK + deep link
 *   3. APK downloads from /enroll/apk/:apkToken
 *   4. Installed app calls /enroll/complete with the same invite token
 *   5. We create/upsert the employee User, create the Device, mint a device
 *      JWT, and (exactly once per device) email the admin that the device
 *      is now connected.
 *
 * The two tokens (invite + apk) are separate so the APK URL can be rotated
 * or revoked independently of the invite itself.
 */
@Injectable()
export class EnrollService implements OnModuleInit {
  private readonly logger = new Logger(EnrollService.name);
  private readonly apkDir: string;
  private readonly appUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly deviceJwt: DeviceJwtService,
    config: ConfigService,
  ) {
    // Overrideable so prod can mount a shared volume.
    this.apkDir = resolve(
      config.get<string>('APK_DIR') ?? join(process.cwd(), 'apk'),
    );
    this.appUrl = (
      config.get<string>('APP_URL') ?? 'http://localhost:3000'
    ).replace(/\/+$/, '');
  }

  onModuleInit(): void {
    if (!existsSync(this.apkDir)) {
      try {
        mkdirSync(this.apkDir, { recursive: true });
      } catch (err) {
        this.logger.warn(
          `Could not create APK dir ${this.apkDir}: ${err instanceof Error ? err.message : err}`,
        );
      }
    }
    const apkPath = join(this.apkDir, APK_FILENAME);
    if (!existsSync(apkPath)) {
      this.logger.warn(
        `APK missing at ${apkPath}. Drop the signed build there so /enroll/apk/:token can serve it.`,
      );
    }
  }

  // ─── Admin: create invite ─────────────────────────────────────────────

  async createInvite(adminId: string, dto: CreateEnrollmentInviteDto) {
    const email = dto.email.trim().toLowerCase();
    const token = randomBytes(32).toString('hex');
    const apkToken = randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

    const invite = await this.prisma.enrollmentInvite.create({
      data: {
        email,
        token,
        apkToken,
        createdByAdminId: adminId,
        expiresAt,
      },
    });

    // Persist the invited name on the User row even before enrollment, so
    // the admin can see "pending: Alice <alice@corp.com>" in the UI. Upsert
    // because a prior invite (or legacy row) might already exist.
    if (dto.firstName || dto.lastName) {
      await this.prisma.user.upsert({
        where: { email },
        update: { firstName: dto.firstName, lastName: dto.lastName },
        create: {
          email,
          role: UserRole.EMPLOYEE,
          firstName: dto.firstName,
          lastName: dto.lastName,
        },
      });
    }

    const employeeName =
      [dto.firstName, dto.lastName].filter(Boolean).join(' ') || undefined;
    await this.mail.sendEnrollmentInvite(email, token, employeeName);

    return {
      inviteId: invite.id,
      email,
      expiresAt: invite.expiresAt,
      inviteUrl: `${this.appUrl}/api/enroll/i/${token}`,
      // The APK URL isn't returned to the admin — it's served from the
      // landing page the employee opens. Returning it would make it easier
      // to leak out of band.
    };
  }

  // ─── Public: landing page HTML ────────────────────────────────────────

  async getLandingPage(token: string): Promise<string> {
    // Deliberately bypass loadInvite()'s throws: the landing page needs to
    // render a friendly explanation for consumed/expired states instead of
    // raising a 404/400 that the mobile browser would show as a raw JSON blob.
    const invite = await this.prisma.enrollmentInvite.findUnique({
      where: { token },
    });
    const notFound = !invite;
    const apkUrl = invite
      ? `${this.appUrl}/api/enroll/apk/${invite.apkToken}`
      : '';
    const deepLink = invite
      ? `nox://enroll?token=${encodeURIComponent(invite.token)}`
      : '';
    const consumed = invite ? invite.consumedAt !== null : false;
    const expired = invite
      ? invite.expiresAt.getTime() <= Date.now()
      : false;

    // Minimal self-contained HTML — no CSS deps, no inline JS beyond a tiny
    // UA sniff. Keeping it dumb so it works on any Android browser.
    const safe = (s: string) =>
      s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');

    const status = consumed
      ? '<p class="err">This invite has already been used. Ask your admin for a new one.</p>'
      : expired
        ? '<p class="err">This invite has expired. Ask your admin for a new one.</p>'
        : notFound
          ? '<p class="err">We couldn\'t find that invite. Double-check the link your admin sent.</p>'
          : `
          <p>Welcome. To finish enrollment:</p>
          <ol>
            <li>Tap <strong>Download NOX</strong> below.</li>
            <li>When the download finishes, open the APK and tap <strong>Install</strong>. You may need to allow "Install unknown apps" first.</li>
            <li>After install, tap <strong>Open NOX</strong> to finish setup.</li>
          </ol>
          <a class="btn" href="${safe(apkUrl)}">Download NOX</a>
          <a class="btn alt" href="${safe(deepLink)}">Open NOX</a>
          <p class="hint">For: <strong>${safe(invite!.email)}</strong></p>
        `;

    return `<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NOX — Enroll your device</title>
<style>
  :root { color-scheme: dark; }
  html,body { margin:0; padding:0; background:#050505; color:#fff;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 480px; margin: 0 auto; padding: 40px 24px; }
  h1 { font-size: 28px; letter-spacing: 6px; margin: 0 0 8px; }
  .accent { width: 36px; height: 3px; background:#00e5ff; border-radius:2px; margin: 0 0 32px; }
  p, li { color:#ccc; line-height:1.6; font-size: 15px; }
  ol { padding-left: 20px; }
  .btn { display:block; margin: 20px 0; padding: 14px 20px; background:#00e5ff; color:#0a0a0a;
    text-decoration:none; border-radius:10px; font-weight:700; text-align:center; }
  .btn.alt { background:#1a1a2e; color:#fff; border:1px solid #2a2a3e; }
  .hint { color:#666; font-size: 13px; margin-top: 32px; }
  .err { background:#2a1a1a; border:1px solid #553333; padding:16px; border-radius:10px; color:#ffbcbc; }
</style>
</head><body><main>
  <h1>NOX</h1><div class="accent"></div>
  ${status}
</main></body></html>`;
  }

  // ─── Public: APK stream ───────────────────────────────────────────────

  /**
   * Returns a readable stream + content-length for the APK file, after
   * validating the apkToken belongs to a live (non-consumed, non-expired)
   * invite. The invite itself is NOT consumed here — that happens only when
   * the installed app calls /enroll/complete. Re-downloads are allowed in
   * case the user clears the APK before installing.
   */
  async openApkForDownload(apkToken: string) {
    const invite = await this.prisma.enrollmentInvite.findUnique({
      where: { apkToken },
    });
    if (!invite) throw new NotFoundException('Invalid APK link');
    if (invite.consumedAt) {
      // Signal 410 Gone to the client. BadRequest is close enough without
      // adding a dedicated exception filter.
      throw new BadRequestException('This enrollment is already complete');
    }
    if (invite.expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException('This enrollment link has expired');
    }

    const apkPath = join(this.apkDir, APK_FILENAME);
    try {
      const info = await stat(apkPath);
      if (!info.isFile()) throw new Error('not a file');
      return {
        stream: createReadStream(apkPath),
        length: info.size,
        filename: APK_FILENAME,
      };
    } catch {
      throw new NotFoundException(
        'APK not available yet. Ask your admin to upload the signed build.',
      );
    }
  }

  // ─── Public: permanent APK download (no token) ─────────────────────────

  /**
   * Serves a build straight from the APK directory by its logical "kind",
   * with NO invite token required. This powers the permanent QR codes that
   * get handed out for self-install (target/agent now; admin can be added
   * when its signed build is dropped in the same folder).
   *
   * Unlike openApkForDownload(), this is not tied to an invite lifecycle —
   * the URL stays valid forever, which is the whole point of a stable QR.
   */
  async openPublicApk(kind: string) {
    const filename = PUBLIC_APKS[kind];
    if (!filename) {
      throw new NotFoundException(`Unknown app "${kind}"`);
    }
    const apkPath = join(this.apkDir, filename);
    try {
      const info = await stat(apkPath);
      if (!info.isFile()) throw new Error('not a file');
      return {
        stream: createReadStream(apkPath),
        length: info.size,
        filename,
      };
    } catch {
      throw new NotFoundException(
        `"${kind}" build is not available on the server yet.`,
      );
    }
  }

  // ─── Public: version metadata (for in-app auto-update) ────────────────

  /**
   * Returns version metadata for the currently-published APK. Shape:
   *   { versionCode?, versionName?, mandatory, notes, size, sha256, mtime,
   *     downloadUrl }
   *
   * The installed agent polls this and compares `versionCode` (preferred)
   * or `sha256` (fallback) against its own package info to decide if an
   * update is available.
   *
   * `versionCode`, `versionName`, `mandatory` and `notes` come from an
   * optional sibling file `manifest.json` in APK_DIR:
   *   {
   *     "agent":  { "versionCode": 2, "versionName": "1.0.1",
   *                 "mandatory": false, "notes": "..." },
   *     "admin":  { ... }
   *   }
   * If `manifest.json` is missing or the kind entry is absent, those
   * fields come back as null — the agent falls back to sha256 comparison.
   */
  async getPublicApkVersion(kind: string): Promise<{
    kind: string;
    versionCode: number | null;
    versionName: string | null;
    mandatory: boolean;
    notes: string;
    size: number;
    sha256: string;
    mtime: string;
    downloadUrl: string;
  }> {
    const filename = PUBLIC_APKS[kind];
    if (!filename) {
      throw new NotFoundException(`Unknown app "${kind}"`);
    }
    const apkPath = join(this.apkDir, filename);
    let info;
    try {
      info = await stat(apkPath);
      if (!info.isFile()) throw new Error('not a file');
    } catch {
      throw new NotFoundException(
        `"${kind}" build is not available on the server yet.`,
      );
    }

    // Hash is cheap (<100ms for a 55MB APK) and only runs when the device
    // explicitly asks for the version. If the hot path turns out to be a
    // bottleneck we can cache by (path, mtime, size) in a Map.
    const buf = await readFile(apkPath);
    const sha256 = createHash('sha256').update(buf).digest('hex');

    const manifest = await this.loadApkManifest();
    const entry = manifest[kind] ?? {};

    return {
      kind,
      versionCode:
        typeof entry.versionCode === 'number' ? entry.versionCode : null,
      versionName:
        typeof entry.versionName === 'string' ? entry.versionName : null,
      mandatory: entry.mandatory === true,
      notes: typeof entry.notes === 'string' ? entry.notes : '',
      size: info.size,
      sha256,
      mtime: info.mtime.toISOString(),
      downloadUrl: `${this.appUrl}/api/enroll/download/${kind}`,
    };
  }

  /**
   * Reads the (optional) `manifest.json` that lives alongside the APK files.
   * Missing or malformed → empty object. Never throws — the version endpoint
   * must stay responsive even if the admin hasn't produced a manifest yet.
   */
  private async loadApkManifest(): Promise<
    Record<
      string,
      {
        versionCode?: number;
        versionName?: string;
        mandatory?: boolean;
        notes?: string;
      }
    >
  > {
    const path = join(this.apkDir, 'manifest.json');
    try {
      const raw = await readFile(path, 'utf8');
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<
          string,
          {
            versionCode?: number;
            versionName?: string;
            mandatory?: boolean;
            notes?: string;
          }
        >;
      }
    } catch {
      // No manifest / bad JSON — treat as empty.
    }
    return {};
  }

  // ─── Device: complete enrollment ──────────────────────────────────────

  async completeEnrollment(
    dto: CompleteEnrollmentDto,
  ): Promise<EnrollmentCompleteResponse> {
    const invite = await this.loadInvite(dto.token, { allowConsumed: false });

    // Upsert the employee User. If they already exist (e.g. legacy from the
    // admin.addDevice flow), we take ownership of the row without overwriting
    // a password they may have set.
    const employee = await this.prisma.user.upsert({
      where: { email: invite.email },
      update: {},
      create: {
        email: invite.email,
        role: UserRole.EMPLOYEE,
      },
    });

    // Derive a default device name if the client didn't provide one.
    const deviceName =
      dto.deviceName?.trim() ||
      invite.email.split('@')[0] ||
      `Device ${invite.id.slice(0, 6)}`;

    const now = new Date();

    // We do create + mark-invite-consumed in a single transaction so a crash
    // between the two can't leave an orphaned device without a consumed
    // invite (which would allow replaying the token).
    const [device] = await this.prisma.$transaction([
      this.prisma.device.create({
        data: {
          name: deviceName,
          // Keep legacy ownerId pointing at the admin for backward compat
          // with existing admin UIs that filter devices by ownerId.
          ownerId: invite.createdByAdminId,
          managedByAdminId: invite.createdByAdminId,
          employeeEmail: invite.email,
          employeeUserId: employee.id,
          isPaired: true,
          firstPairedAt: now,
          firstConnectedAt: now,
          // firstConnectedEmailSentAt is set below AFTER we've successfully
          // sent the email so a mail-service failure doesn't permanently
          // suppress the "device connected" notification.
          deviceModel: dto.deviceModel,
          osVersion: dto.osVersion,
          appVersion: dto.appVersion,
        },
      }),
      this.prisma.enrollmentInvite.update({
        where: { id: invite.id },
        data: { consumedAt: now },
      }),
    ]);

    // Backfill the invite→device link now that we have the device id.
    await this.prisma.enrollmentInvite.update({
      where: { id: invite.id },
      data: { deviceId: device.id },
    });

    // Store the device's FCM token on the employee User row so future
    // commands/alerts can reach it. (The admin's FCM token lives on the
    // admin User row and is set via a separate endpoint.)
    if (dto.fcmToken) {
      await this.prisma.user
        .update({
          where: { id: employee.id },
          data: { fcmToken: dto.fcmToken },
        })
        .catch((err) =>
          this.logger.warn(
            `fcmToken save failed for ${employee.email}: ${err instanceof Error ? err.message : err}`,
          ),
        );
    }

    // Send the admin exactly ONE "device connected" email, ever, per device.
    // Guard uses firstConnectedEmailSentAt as the atomic flag — if sending
    // succeeds we stamp it; if we crash before stamping, next enrollment
    // call (which won't happen since the invite is consumed) wouldn't retry.
    // That means the alert can be dropped on a mail-service outage; this is
    // an accepted trade-off vs. the risk of double-emailing.
    void this.sendConnectedEmailOnce(device.id, invite.createdByAdminId);

    return {
      deviceId: device.id,
      deviceToken: this.deviceJwt.sign(device.id, device.ownerId),
      ownerId: invite.createdByAdminId,
      employee: { id: employee.id, email: employee.email },
      deviceName: device.name,
    };
  }

  private async sendConnectedEmailOnce(
    deviceId: string,
    adminId: string,
  ): Promise<void> {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device || device.firstConnectedEmailSentAt) return;

    const admin = await this.prisma.user.findUnique({ where: { id: adminId } });
    if (!admin) return;

    try {
      await this.mail.sendDeviceConnected(
        admin.email,
        device.employeeEmail ?? '(unknown)',
        device.name,
        device.deviceModel,
      );
      await this.prisma.device.update({
        where: { id: deviceId },
        data: { firstConnectedEmailSentAt: new Date() },
      });
    } catch (err) {
      this.logger.error(
        `sendDeviceConnected failed for device ${deviceId}: ${err instanceof Error ? err.message : err}`,
      );
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────

  private async loadInvite(
    token: string,
    opts: { allowConsumed?: boolean } = {},
  ) {
    const invite = await this.prisma.enrollmentInvite.findUnique({
      where: { token },
    });
    if (!invite) throw new NotFoundException('Invalid or expired invite');
    if (!opts.allowConsumed && invite.consumedAt) {
      throw new BadRequestException('This invite has already been used');
    }
    if (invite.expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException('This invite has expired');
    }
    return invite;
  }
}

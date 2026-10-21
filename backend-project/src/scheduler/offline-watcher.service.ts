import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service.js';
import { MailService } from '../auth/mail.service.js';
import { FcmService } from '../fcm/fcm.service.js';
import { NoxGateway } from '../gateway/nox.gateway.js';

/**
 * Marks devices offline when they stop heartbeating. Runs every 60 seconds.
 *
 * Semantics:
 *   - A device is considered live if lastSeenAt > now - OFFLINE_THRESHOLD_MS.
 *   - On the transition online→offline we flip isOnline=false, broadcast to
 *     admins via WebSocket, send ONE email per outage, and send ONE FCM push
 *     per outage. `offlineAlertSentAt` is the atomic flag that prevents
 *     repeated alerts during the same outage; it's cleared by the heartbeat
 *     endpoint when the device comes back.
 *
 * The threshold is intentionally longer than the heartbeat interval (default
 * 60s on the agent) × 3 so brief network blips don't trigger alerts.
 */
@Injectable()
export class OfflineWatcherService {
  private readonly logger = new Logger(OfflineWatcherService.name);
  private readonly thresholdMs: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly fcm: FcmService,
    private readonly gateway: NoxGateway,
    config: ConfigService,
  ) {
    this.thresholdMs = Number(
      config.get<string>('OFFLINE_THRESHOLD_MS') ?? 3 * 60 * 1000,
    );
  }

  @Cron(CronExpression.EVERY_MINUTE)
  async sweep(): Promise<void> {
    const cutoff = new Date(Date.now() - this.thresholdMs);

    // Find devices that are *still marked online* but haven't been seen
    // recently and that we haven't already alerted on in this outage. We
    // require lastSeenAt to be non-null so we don't alert on freshly
    // enrolled devices that never heartbeated.
    const stale = await this.prisma.device.findMany({
      where: {
        isOnline: true,
        lastSeenAt: { lt: cutoff, not: null },
        offlineAlertSentAt: null,
      },
      include: {
        managedByAdmin: { select: { email: true, fcmToken: true } },
      },
      take: 50, // batch cap, next tick picks up the rest
    });

    if (stale.length === 0) return;

    this.logger.log(`Marking ${stale.length} device(s) offline`);

    const now = new Date();
    for (const device of stale) {
      try {
        // Transition device + remember we alerted in one update. If this
        // row is concurrently updated by a late heartbeat, the heartbeat's
        // offlineAlertSentAt=null will win and the next sweep will re-alert
        // if the device later goes offline again — the desired behavior.
        await this.prisma.device.update({
          where: { id: device.id },
          data: { isOnline: false, offlineAlertSentAt: now },
        });

        const adminEmail = device.managedByAdmin?.email;
        const adminFcm = device.managedByAdmin?.fcmToken;
        const lastSeen = device.lastSeenAt ?? now;
        const employeeEmail = device.employeeEmail ?? '(unknown)';

        // Broadcast to all admin sockets
        this.gateway.sendToAdmins('admin:device-offline', {
          deviceId: device.id,
          deviceName: device.name,
          employeeEmail,
          lastSeenAt: lastSeen.toISOString(),
          message: `${device.name} (${employeeEmail}) is offline`,
        });

        // One email per outage, to the managing admin only
        if (adminEmail) {
          await this.mail
            .sendDeviceOffline(adminEmail, employeeEmail, device.name, lastSeen)
            .catch((err) =>
              this.logger.error(
                `sendDeviceOffline failed for ${adminEmail}: ${err instanceof Error ? err.message : err}`,
              ),
            );
        }

        // One FCM push per outage
        if (adminFcm) {
          await this.fcm.sendToTokens([adminFcm], {
            title: 'Device offline',
            body: `${device.name} (${employeeEmail}) stopped reporting`,
            data: {
              type: 'DEVICE_OFFLINE',
              deviceId: device.id,
              lastSeenAt: lastSeen.toISOString(),
            },
            urgent: true,
          });
        }
      } catch (err) {
        this.logger.error(
          `offline sweep failed for device ${device.id}: ${err instanceof Error ? err.message : err}`,
        );
      }
    }
  }
}

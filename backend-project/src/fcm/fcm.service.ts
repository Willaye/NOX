import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFileSync } from 'node:fs';

/**
 * Thin wrapper around firebase-admin for sending FCM push notifications to
 * the admin app. Designed to degrade gracefully: if no service account is
 * configured, every send() becomes a no-op and the rest of the app keeps
 * running — mirroring how MailService handles missing SMTP creds.
 *
 * Configuration (any one of):
 *   FIREBASE_SERVICE_ACCOUNT_JSON   — the full service-account JSON inlined
 *   FIREBASE_SERVICE_ACCOUNT_PATH   — a path to the service-account JSON file
 *
 * Both are optional in dev. The service account is loaded synchronously at
 * boot so initialization errors show up at startup rather than at first push.
 */
@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  // Dynamic admin so firebase-admin isn't a hard dependency for dev runs that
  // don't configure FCM. Loaded lazily inside onModuleInit().
  private admin: typeof import('firebase-admin') | null = null;
  private app: import('firebase-admin').app.App | null = null;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const inline = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    const path = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');

    if (!inline && !path) {
      this.logger.warn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      this.logger.warn('🔔 FCM not configured — running in DEV MODE');
      this.logger.warn('   Pushes will NOT be sent.');
      this.logger.warn('   Set FIREBASE_SERVICE_ACCOUNT_JSON or');
      this.logger.warn('   FIREBASE_SERVICE_ACCOUNT_PATH in .env to enable.');
      this.logger.warn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    let credential: Record<string, unknown>;
    try {
      const raw = inline ?? readFileSync(path as string, 'utf8');
      credential = JSON.parse(raw) as Record<string, unknown>;
    } catch (err) {
      this.logger.error(
        `FCM init failed — could not read/parse service account: ${err instanceof Error ? err.message : err}`,
      );
      return;
    }

    try {
      // Dynamic import keeps firebase-admin out of the hot startup path when
      // the service is unused in dev. Also avoids CommonJS/ESM interop issues
      // at module-load time.
      const mod = await import('firebase-admin');
      this.admin = (mod as unknown as { default?: typeof mod }).default ?? mod;
      // If someone already created the default app (e.g. in tests), reuse it.
      this.app =
        this.admin.apps.length > 0
          ? this.admin.app()
          : this.admin.initializeApp({
              credential: this.admin.credential.cert(credential as import('firebase-admin').ServiceAccount),
            });
      this.logger.log('✅ FCM initialized');
    } catch (err) {
      this.logger.error(
        `FCM init failed: ${err instanceof Error ? err.message : err}`,
      );
      this.app = null;
    }
  }

  /** True if the service has a usable Firebase app. */
  isEnabled(): boolean {
    return this.app !== null;
  }

  /**
   * Send a push to a list of device tokens. Returns the number of successful
   * sends. Invalid tokens are logged but do not throw.
   *
   * Payload shape is intentionally minimal to match what the admin app needs:
   *   - a visible notification (title/body)
   *   - a data payload for in-app routing
   */
  async sendToTokens(
    tokens: string[],
    payload: {
      title: string;
      body: string;
      data?: Record<string, string>;
      // Set true for time-sensitive alerts (unlock, offline). On Android this
      // delivers immediately even in Doze; on iOS it bumps priority.
      urgent?: boolean;
    },
  ): Promise<number> {
    if (!this.app || !this.admin || tokens.length === 0) return 0;

    const message: import('firebase-admin').messaging.MulticastMessage = {
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
      android: {
        priority: payload.urgent ? 'high' : 'normal',
        notification: {
          // Buzzer-like default channel on the admin device; the client should
          // create a channel with sound/vibration enabled for this id.
          channelId: payload.urgent ? 'nox_alerts_urgent' : 'nox_alerts',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        headers: payload.urgent ? { 'apns-priority': '10' } : undefined,
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    try {
      const resp = await this.admin.messaging().sendEachForMulticast(message);
      if (resp.failureCount > 0) {
        resp.responses.forEach((r, i) => {
          if (!r.success) {
            this.logger.warn(
              `FCM failed for token ${tokens[i].slice(0, 10)}…: ${r.error?.message}`,
            );
          }
        });
      }
      return resp.successCount;
    } catch (err) {
      this.logger.error(
        `FCM send error: ${err instanceof Error ? err.message : err}`,
      );
      return 0;
    }
  }
}

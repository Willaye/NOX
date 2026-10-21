import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface MailTransporter {
  sendMail(options: {
    from: string;
    to: string;
    subject: string;
    text: string;
    html: string;
  }): Promise<Record<string, unknown>>;
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly smtpHost?: string;
  private readonly smtpPort: number;
  private readonly smtpUser?: string;
  private readonly smtpPass?: string;
  private readonly smtpFrom: string;
  private readonly appUrl: string;
  // Brevo (Sendinblue) transactional email HTTP API. Preferred on hosts that
  // block outbound SMTP ports (e.g. Railway Hobby/Trial blocks 25/465/587),
  // because this call goes over HTTPS/443 which is always allowed.
  private readonly brevoApiKey?: string;
  private readonly senderName: string;
  private readonly senderEmail: string;
  private transporter?: MailTransporter | null;
  private initialized = false;

  constructor(config: ConfigService) {
    this.smtpHost = config.get<string>('SMTP_HOST') || undefined;
    this.smtpPort = Number(config.get<string>('SMTP_PORT') ?? 587);
    this.smtpUser = config.get<string>('SMTP_USER') || undefined;
    this.smtpPass = config.get<string>('SMTP_PASS') || undefined;
    this.smtpFrom =
      config.get<string>('SMTP_FROM') ?? 'NOX <noreply@nox.dev>';
    this.appUrl = (
      config.get<string>('APP_URL') ?? 'http://localhost:3000'
    ).replace(/\/+$/, '');

    this.brevoApiKey = config.get<string>('BREVO_API_KEY') || undefined;

    // Parse `Name <email>` (falls back gracefully to a bare address).
    const fromMatch = this.smtpFrom.match(/^\s*(.*?)\s*<([^>]+)>\s*$/);
    this.senderName = (fromMatch?.[1] || 'NOX').replace(/"/g, '').trim();
    this.senderEmail = (
      fromMatch?.[2] ||
      this.smtpFrom ||
      this.smtpUser ||
      'noreply@nox.dev'
    ).trim();
  }

  private async getTransporter(): Promise<MailTransporter | null> {
    if (this.initialized) return this.transporter ?? null;
    this.initialized = true;

    if (!this.smtpHost || !this.smtpUser || !this.smtpPass) {
      this.logger.warn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      this.logger.warn('📧 SMTP not configured — running in DEV MODE');
      this.logger.warn('   Emails will NOT be sent.');
      this.logger.warn('   Dashboard auto-login is enabled.');
      this.logger.warn('   Set SMTP_HOST, SMTP_USER, SMTP_PASS in .env');
      this.logger.warn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      this.transporter = null;
      return null;
    }

    try {
      const moduleName = 'nodemailer';
      const nodemailer = await import(moduleName);
      const createTransport =
        nodemailer.createTransport ?? nodemailer.default?.createTransport;

      this.transporter = createTransport({
        host: this.smtpHost,
        port: this.smtpPort,
        secure: this.smtpPort === 465,
        auth: { user: this.smtpUser, pass: this.smtpPass },
        // Fail fast instead of hanging the HTTP request for ~2 minutes when
        // the host blocks outbound SMTP (Railway) or the server is slow.
        connectionTimeout: 8000,
        greetingTimeout: 8000,
        socketTimeout: 10000,
      }) as MailTransporter;

      this.logger.log(`✅ SMTP ready: ${this.smtpHost}:${this.smtpPort} (${this.smtpFrom})`);
      return this.transporter;
    } catch (err) {
      this.logger.error(`SMTP setup failed: ${err instanceof Error ? err.message : err}`);
      this.transporter = null;
      return null;
    }
  }

  // ─── Send Magic Link ──────────────────────────────────────────────────

  async sendMagicLink(email: string, token: string): Promise<boolean> {
    const link = `${this.appUrl}/api/auth/verify?token=${encodeURIComponent(token)}`;

    const sent = await this.send(
      email,
      '🔐 NOX — Your Sign-In Code',
      `NOX — Device Management\n\nYour verification token:\n\n${token}\n\nThis expires in 15 minutes.\n\nOr click: ${link}\n\n— NOX Team`,
      this.template({
        preheader: 'Your NOX sign-in verification code',
        title: 'Sign In to NOX',
        body: `
          <p style="margin:0 0 20px;color:#cccccc;font-size:15px;line-height:1.6">
            Use the code below to sign in. It expires in <strong style="color:#fff">15 minutes</strong>.
          </p>
          <div style="background:#1a1a2e;border:2px solid #00e5ff;border-radius:12px;padding:24px;text-align:center;margin:24px 0">
            <p style="margin:0 0 8px;font-size:12px;color:#888;text-transform:uppercase;letter-spacing:2px">Verification Code</p>
            <p style="margin:0;font-size:18px;font-family:'Courier New',monospace;color:#00e5ff;word-break:break-all;letter-spacing:1px;font-weight:700">${this.esc(token)}</p>
          </div>
          <p style="margin:20px 0;text-align:center">
            <a href="${this.esc(link)}" style="display:inline-block;padding:14px 36px;background:#00e5ff;color:#0a0a0a;text-decoration:none;border-radius:8px;font-weight:700;font-size:15px">Sign In to NOX</a>
          </p>
          <p style="margin:24px 0 0;font-size:13px;color:#555;text-align:center">If you didn't request this, ignore this email.</p>`,
      }),
    );

    if (!sent) {
      // Only log the raw token when running in dev mode. In production this
      // would leak a sign-in secret to log sinks if SMTP ever fails.
      if (process.env.NODE_ENV !== 'production') {
        this.logger.warn(`[DEV] Magic link for ${email}: token=${token}`);
      } else {
        this.logger.error(`Magic link email delivery failed for ${email}`);
      }
    }
    return sent;
  }

  // ─── Device Alert ─────────────────────────────────────────────────────

  async sendDeviceAlert(email: string, title: string, message: string): Promise<void> {
    const time = new Date().toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' });

    const sent = await this.send(
      email,
      `🔔 NOX — ${title}`,
      `NOX Alert\n\n${title}\n${message}\n\nTime: ${time}\n\n— NOX Team`,
      this.template({
        preheader: title,
        title: '🔔 Device Alert',
        body: `
          <div style="background:#1a1a2e;border:2px solid #00e5ff;border-radius:12px;padding:24px;text-align:center;margin:20px 0">
            <p style="margin:0 0 8px;font-size:16px;color:#00e5ff;font-weight:700">${this.esc(title)}</p>
            <p style="margin:0;font-size:14px;color:#ccc">${this.esc(message)}</p>
          </div>
          <p style="margin:0;font-size:13px;color:#666;text-align:center">${this.esc(time)}</p>`,
      }),
    );

    if (!sent) {
      this.logger.warn(`[DEV] Alert for ${email}: ${title}`);
    }
  }

  // ─── Device Paired Alert ──────────────────────────────────────────────

  async sendDevicePairedAlert(email: string, deviceName: string): Promise<void> {
    const time = new Date().toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' });

    const sent = await this.send(
      email,
      '📱 NOX — New Device Paired',
      `NOX\n\nDevice "${deviceName}" paired at ${time}.\n\n— NOX Team`,
      this.template({
        preheader: `Device "${deviceName}" paired`,
        title: 'New Device Paired',
        body: `
          <div style="background:#1a1a2e;border:1px solid #2a2a3e;border-radius:12px;padding:20px;margin:20px 0">
            <p style="margin:0 0 12px;font-size:13px;color:#888;text-transform:uppercase;letter-spacing:1px">Device</p>
            <p style="margin:0;font-size:18px;color:#fff;font-weight:600">${this.esc(deviceName)}</p>
          </div>
          <p style="margin:0;font-size:14px;color:#ccc">Paired on <strong style="color:#fff">${this.esc(time)}</strong></p>
          <p style="margin:20px 0 0;font-size:13px;color:#ff4757;background:rgba(255,71,87,0.1);padding:12px 16px;border-radius:8px">⚠️ If this wasn't you, contact your administrator.</p>`,
      }),
    );

    if (!sent) {
      this.logger.warn(`[DEV] Device paired: ${email} → "${deviceName}"`);
    }
  }

  // ─── Enrollment Invite (sent to employee) ─────────────────────────────

  /**
   * Email the employee a link that opens the APK landing page. The landing
   * page detects Android and offers the install (and later deep-links back
   * into the app with the same token).
   */
  async sendEnrollmentInvite(
    email: string,
    inviteToken: string,
    employeeName?: string,
  ): Promise<void> {
    const link = `${this.appUrl}/api/enroll/i/${encodeURIComponent(inviteToken)}`;
    const greet = employeeName ? `Hi ${employeeName},` : 'Hi,';

    const sent = await this.send(
      email,
      '📲 NOX — Set up your work device',
      `${greet}\n\nYour administrator has invited you to enroll this device in NOX.\n\nOpen the link below on the device you want to enroll. It will walk you through installing the NOX agent.\n\n${link}\n\nThis link expires in 7 days.\n\n— NOX Team`,
      this.template({
        preheader: 'Set up your work device',
        title: 'Enroll your device',
        body: `
          <p style="margin:0 0 20px;color:#cccccc;font-size:15px;line-height:1.6">
            ${this.esc(greet)}<br><br>
            Your administrator has invited you to enroll this device in NOX.
            Open the button below <strong style="color:#fff">on the Android
            device you want to enroll</strong>.
          </p>
          <p style="margin:20px 0;text-align:center">
            <a href="${this.esc(link)}" style="display:inline-block;padding:14px 36px;background:#00e5ff;color:#0a0a0a;text-decoration:none;border-radius:8px;font-weight:700;font-size:15px">Open on your device</a>
          </p>
          <p style="margin:24px 0 0;font-size:13px;color:#555;text-align:center">This link expires in 7 days.</p>`,
      }),
    );

    if (!sent) {
      this.logger.warn(`[DEV] Enrollment invite for ${email}: ${link}`);
    }
  }

  // ─── Device Connected (sent to admin exactly once per device) ─────────

  /**
   * Fired by the enrollment service the first time a device successfully
   * calls /enroll/complete. Caller is responsible for the idempotency guard
   * (Device.firstConnectedEmailSentAt); this method just formats and sends.
   */
  async sendDeviceConnected(
    adminEmail: string,
    employeeEmail: string,
    deviceName: string,
    deviceModel: string | null,
  ): Promise<void> {
    const time = new Date().toLocaleString('en-US', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });
    const modelLine = deviceModel ? ` (${deviceModel})` : '';

    const sent = await this.send(
      adminEmail,
      `✅ NOX — ${employeeEmail} connected a device`,
      `NOX\n\n${employeeEmail} enrolled "${deviceName}"${modelLine} at ${time}.\n\n— NOX Team`,
      this.template({
        preheader: `${employeeEmail} enrolled ${deviceName}`,
        title: 'Device connected',
        body: `
          <div style="background:#1a1a2e;border:1px solid #2a2a3e;border-radius:12px;padding:20px;margin:20px 0">
            <p style="margin:0 0 6px;font-size:12px;color:#888;text-transform:uppercase;letter-spacing:1px">Employee</p>
            <p style="margin:0 0 14px;font-size:16px;color:#fff">${this.esc(employeeEmail)}</p>
            <p style="margin:0 0 6px;font-size:12px;color:#888;text-transform:uppercase;letter-spacing:1px">Device</p>
            <p style="margin:0;font-size:16px;color:#fff">${this.esc(deviceName)}${this.esc(modelLine)}</p>
          </div>
          <p style="margin:0;font-size:14px;color:#ccc">Connected on <strong style="color:#fff">${this.esc(time)}</strong>. You can now view live data in the NOX admin app.</p>`,
      }),
    );

    if (!sent) {
      this.logger.warn(
        `[DEV] Device connected: admin=${adminEmail} employee=${employeeEmail} device=${deviceName}`,
      );
    }
  }

  // ─── Device Offline (sent to admin at most once per offline window) ──

  async sendDeviceOffline(
    adminEmail: string,
    employeeEmail: string,
    deviceName: string,
    lastSeenAt: Date,
  ): Promise<void> {
    const seen = lastSeenAt.toLocaleString('en-US', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });

    const sent = await this.send(
      adminEmail,
      `⚠️ NOX — ${deviceName} is offline`,
      `NOX\n\n${deviceName} (${employeeEmail}) stopped reporting at ${seen}.\n\n— NOX Team`,
      this.template({
        preheader: `${deviceName} stopped reporting`,
        title: 'Device offline',
        body: `
          <div style="background:#2a1a1a;border:1px solid #553333;border-radius:12px;padding:20px;margin:20px 0">
            <p style="margin:0 0 6px;font-size:12px;color:#ff8a8a;text-transform:uppercase;letter-spacing:1px">Device</p>
            <p style="margin:0 0 14px;font-size:16px;color:#fff">${this.esc(deviceName)} <span style="color:#888">— ${this.esc(employeeEmail)}</span></p>
            <p style="margin:0 0 6px;font-size:12px;color:#ff8a8a;text-transform:uppercase;letter-spacing:1px">Last Seen</p>
            <p style="margin:0;font-size:16px;color:#fff">${this.esc(seen)}</p>
          </div>
          <p style="margin:0;font-size:14px;color:#ccc">The device has stopped sending heartbeats. This may indicate the agent was stopped, uninstalled, or the device is powered off / out of connectivity.</p>`,
      }),
    );

    if (!sent) {
      this.logger.warn(
        `[DEV] Device offline: admin=${adminEmail} device=${deviceName}`,
      );
    }
  }

  // ─── Core Send ────────────────────────────────────────────────────────

  private async send(to: string, subject: string, text: string, html: string): Promise<boolean> {
    // 1) Prefer the Brevo HTTP API when configured. This is the reliable path
    //    on hosts that block outbound SMTP (Railway), since it uses HTTPS/443.
    if (this.brevoApiKey) {
      const ok = await this.sendViaBrevo(to, subject, text, html);
      if (ok) return true;
      // If Brevo fails, fall through to SMTP (if any) as a backup.
    }

    // 2) Fall back to SMTP (nodemailer).
    const transporter = await this.getTransporter();
    if (!transporter) return false;

    try {
      await transporter.sendMail({ from: this.smtpFrom, to, subject, text, html });
      this.logger.log(`📧 Email sent to ${to}: "${subject}"`);
      return true;
    } catch (err) {
      this.logger.error(`❌ Email failed to ${to}: ${err instanceof Error ? err.message : err}`);
      return false;
    }
  }

  /**
   * Send a transactional email through Brevo's HTTP API. Works over HTTPS/443,
   * so it is unaffected by SMTP egress blocks. Uses the global fetch available
   * in Node 18+. A hard AbortController timeout guarantees we never hang the
   * caller (and therefore never hang the HTTP request behind it).
   */
  private async sendViaBrevo(
    to: string,
    subject: string,
    text: string,
    html: string,
  ): Promise<boolean> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 10_000);
    try {
      const res = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'api-key': this.brevoApiKey as string,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          sender: { name: this.senderName, email: this.senderEmail },
          to: [{ email: to }],
          subject,
          htmlContent: html,
          textContent: text,
        }),
        signal: controller.signal,
      });

      if (res.ok) {
        this.logger.log(`📧 Email sent to ${to} via Brevo: "${subject}"`);
        return true;
      }

      const detail = await res.text().catch(() => '');
      this.logger.error(
        `❌ Brevo send failed to ${to} (HTTP ${res.status}): ${detail.slice(0, 300)}`,
      );
      return false;
    } catch (err) {
      this.logger.error(
        `❌ Brevo send error to ${to}: ${err instanceof Error ? err.message : err}`,
      );
      return false;
    } finally {
      clearTimeout(timer);
    }
  }

  // ─── NOX Email Template ───────────────────────────────────────────────

  private template(opts: { preheader: string; title: string; body: string }): string {
    return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>NOX</title></head>
<body style="margin:0;padding:0;background:#050505;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#fff">
  <div style="display:none;max-height:0;overflow:hidden">${this.esc(opts.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#050505;padding:32px 16px">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">
        <tr><td align="center" style="padding:24px 0 32px">
          <span style="font-size:36px;font-weight:900;letter-spacing:8px;color:#fff">NOX</span>
          <div style="width:40px;height:3px;background:#00e5ff;border-radius:2px;margin:8px auto 0"></div>
        </td></tr>
        <tr><td style="background:#111;border:1px solid #222;border-radius:16px;padding:36px 32px">
          <h1 style="margin:0 0 20px;font-size:22px;font-weight:700;color:#fff;text-align:center">${this.esc(opts.title)}</h1>
          ${opts.body}
        </td></tr>
        <tr><td style="padding:32px 0;text-align:center">
          <p style="margin:0 0 8px;font-size:12px;color:#444">Powered by <strong style="color:#555;letter-spacing:2px">NOX</strong> Device Management</p>
          <p style="margin:0;font-size:11px;color:#333">Automated message — do not reply.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
  }

  private esc(v: string): string {
    return v.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
}

import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service.js';

interface AuthenticatedSocket extends Socket {
  data: {
    userId?: string;
    email?: string;
    role?: string;
    deviceId?: string;
  };
}

/**
 * Real-time WebSocket channel for admins and (optionally) devices.
 *
 * Admin sockets join the "admins" room; device sockets join
 * `device:<deviceId>`. The REST side of the API uses `sendToAdmins` and
 * `sendToDevice` to push events — the gateway itself only brokers.
 *
 * Deliberately NOT included (any more): sending emails from connect /
 * disconnect handlers. The two authoritative paths now are:
 *   - enrollment → one email on firstConnect (handled by EnrollService)
 *   - offline-watcher cron → one email per outage transition
 * The gateway still records in-DB notifications and broadcasts the live
 * events, but doesn't call MailService — that was causing one email per
 * socket reconnect.
 */
@WebSocketGateway({
  namespace: '/nox-mdm',
  cors: { origin: '*' },
})
export class NoxGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private logger = new Logger('NoxGateway');
  private connectedDevices = new Map<string, string>();
  private connectedAdmins = new Map<string, string>();

  constructor(
    private jwtService: JwtService,
    private prisma: PrismaService,
  ) {}

  afterInit() {
    this.logger.log('NOX MDM WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token =
        client.handshake.auth?.token ??
        client.handshake.headers?.authorization?.replace('Bearer ', '') ??
        (client.handshake.query?.token as string);

      if (!token) throw new UnauthorizedException('No token');

      // Supports both user tokens (role=ADMIN|EMPLOYEE) and device tokens
      // (typ=device). The caller sets ?deviceId=... in the handshake query
      // when connecting as a device.
      const payload = this.jwtService.verify<{
        sub: string;
        role?: string;
        email?: string;
        typ?: string;
      }>(token);

      const deviceId = (client.handshake.query?.deviceId as string) ?? null;

      if (deviceId || payload.typ === 'device') {
        const id = deviceId ?? payload.sub;
        client.data = { deviceId: id };
        this.connectedDevices.set(id, client.id);
        client.join(`device:${id}`);

        // Flip isOnline true + clear offline-alert state so the next outage
        // can alert again. We do NOT call MailService here any more — that
        // was the source of the per-reconnect email spam.
        await this.prisma.device
          .update({
            where: { id },
            data: {
              isOnline: true,
              lastSeenAt: new Date(),
              offlineAlertSentAt: null,
            },
          })
          .catch(() => null);

        this.sendToAdmins('admin:device-online', {
          deviceId: id,
          timestamp: new Date().toISOString(),
        });
        this.logger.log(`Device ${id} connected`);
      } else {
        const user = await this.prisma.user.findUnique({
          where: { id: payload.sub },
        });
        if (!user) throw new UnauthorizedException('User not found');

        client.data = {
          userId: user.id,
          email: user.email,
          role: user.role,
        };

        if (user.role === 'ADMIN') {
          this.connectedAdmins.set(user.id, client.id);
          client.join('admins');
          this.logger.log(`Admin ${user.email} connected`);
        }
      }

      client.emit('connected', {
        ok: true,
        role: client.data?.role ?? (client.data?.deviceId ? 'DEVICE' : null),
      });
    } catch {
      this.logger.warn('Connection rejected: invalid token');
      client.emit('error', { message: 'Authentication failed' });
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    const deviceId = client.data?.deviceId;
    const userId = client.data?.userId;

    if (deviceId) {
      this.connectedDevices.delete(deviceId);
      // Don't flip isOnline=false here. The offline-watcher cron is now the
      // single source of truth for the offline transition — this prevents
      // Socket.IO reconnect churn (which happens every network blip) from
      // triggering repeated DB writes and alerts.
      this.sendToAdmins('admin:device-socket-disconnect', {
        deviceId,
        timestamp: new Date().toISOString(),
      });
      this.logger.log(`Device ${deviceId} socket disconnected`);
    } else if (userId) {
      this.connectedAdmins.delete(userId);
    }
  }

  // ─── Device → Server Events ─────────────────────────────────────────────

  @SubscribeMessage('device:data')
  handleDeviceData(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { type: string; payload: any },
  ) {
    const deviceId = client.data?.deviceId;
    if (!deviceId) return;
    this.server.to(`device:${deviceId}`).emit('device:data', {
      deviceId,
      type: data.type,
      payload: data.payload,
      timestamp: new Date().toISOString(),
    });
  }

  @SubscribeMessage('device:location')
  async handleDeviceLocation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody()
    data: {
      latitude: number;
      longitude: number;
      accuracy?: number;
      speed?: number;
    },
  ) {
    const deviceId = client.data?.deviceId;
    if (!deviceId) return;

    await this.prisma.locationLog
      .create({
        data: {
          deviceId,
          latitude: data.latitude,
          longitude: data.longitude,
          accuracy: data.accuracy,
          speed: data.speed,
        },
      })
      .catch((err) => this.logger.error(`Location save failed: ${err}`));

    this.sendToAdmins('admin:device-location', {
      deviceId,
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy,
      timestamp: new Date().toISOString(),
    });
  }

  @SubscribeMessage('device:heartbeat')
  async handleDeviceHeartbeat(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { batteryLevel?: number },
  ) {
    const deviceId = client.data?.deviceId;
    if (!deviceId) return;

    await this.prisma.device
      .update({
        where: { id: deviceId },
        data: {
          isOnline: true,
          lastSeenAt: new Date(),
          offlineAlertSentAt: null,
          ...(data.batteryLevel !== undefined
            ? { batteryLevel: data.batteryLevel }
            : {}),
        },
      })
      .catch(() => {});

    this.sendToAdmins('admin:device-heartbeat', {
      deviceId,
      batteryLevel: data.batteryLevel,
      timestamp: new Date().toISOString(),
    });
  }

  // ─── Admin → Server Events ──────────────────────────────────────────────

  @SubscribeMessage('admin:watch')
  handleAdminWatch(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;
    client.join(`device:${data.deviceId}`);
    client.emit('watching', { deviceId: data.deviceId });
  }

  @SubscribeMessage('admin:unwatch')
  handleAdminUnwatch(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    client.leave(`device:${data.deviceId}`);
  }

  // ─── Public helpers for other modules ───────────────────────────────────

  /** Push a payload to a specific device socket, if connected. */
  sendToDevice(deviceId: string, event: string, data: unknown) {
    const socketId = this.connectedDevices.get(deviceId);
    if (socketId) this.server.to(socketId).emit(event, data);
  }

  /** Broadcast to every connected admin. */
  sendToAdmins(event: string, data: unknown) {
    this.server.to('admins').emit(event, data);
  }

  isDeviceOnline(deviceId: string): boolean {
    return this.connectedDevices.has(deviceId);
  }
}

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
import { DeviceService } from '../device/device.service.js';

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
    private deviceService: DeviceService,
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
        // SECURITY FIX: When connecting as a device, verify the deviceId matches
        // the token's subject claim. Previously, a user token with ?deviceId=X
        // could impersonate any device.
        if (payload.typ === 'device') {
          // Device token: the sub IS the deviceId. Trust it.
          const id = payload.sub;
          // If caller also passed ?deviceId, it must match the token.
          if (deviceId && deviceId !== id) {
            throw new UnauthorizedException('Device ID mismatch');
          }
          client.data = { deviceId: id };
          this.connectedDevices.set(id, client.id);
          client.join(`device:${id}`);

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
          // User token with ?deviceId — reject this pattern entirely.
          // Devices MUST use device tokens (typ=device) to connect as devices.
          throw new UnauthorizedException(
            'User tokens cannot connect as devices. Use a device token.',
          );
        }
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
  async handleAdminWatch(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    // SECURITY FIX: Verify this admin manages this device before allowing them
    // to join the device room and receive its events (including screenshots).
    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Device not found or access denied' });
      return;
    }

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

  // Admin requests live screen capture start/stop
  @SubscribeMessage('admin:start-screen-capture')
  async handleStartScreenCapture(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    // SECURITY FIX: Verify ownership before starting screen capture.
    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Device not found or access denied' });
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { command: 'START_SCREEN_CAPTURE' });
    // Join the device room to receive screenshots
    client.join(`device:${data.deviceId}`);
  }

  @SubscribeMessage('admin:stop-screen-capture')
  async handleStopScreenCapture(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    // Verify ownership before stopping screen capture.
    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { command: 'STOP_SCREEN_CAPTURE' });
  }

  // Device sends screenshot → relay to admins watching this device
  @SubscribeMessage('device:screenshot')
  handleDeviceScreenshot(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { data: string; timestamp: string },
  ) {
    const deviceId = client.data?.deviceId;
    if (!deviceId) return;
    // Relay to all admins watching this device (in the device room)
    this.server.to(`device:${deviceId}`).except(client.id).emit('admin:screenshot', {
      deviceId,
      data: data.data,
      timestamp: data.timestamp,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIVE MONITORING FEATURES
  // ═══════════════════════════════════════════════════════════════════════

  // ─── Live Audio (Microphone) ───────────────────────────────────────────

  @SubscribeMessage('admin:start-live-audio')
  async handleStartLiveAudio(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Access denied' });
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { command: 'START_LIVE_AUDIO' });
    client.join(`device:${data.deviceId}`);
    this.logger.log(`Admin ${client.data.userId} started live audio for ${data.deviceId}`);
  }

  @SubscribeMessage('admin:stop-live-audio')
  async handleStopLiveAudio(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) return;

    this.sendToDevice(data.deviceId, 'command', { command: 'STOP_LIVE_AUDIO' });
  }

  // ─── Live Camera ───────────────────────────────────────────────────────

  @SubscribeMessage('admin:start-live-camera')
  async handleStartLiveCamera(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string; front?: boolean },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Access denied' });
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { 
      command: 'START_LIVE_CAMERA',
      front: data.front ?? true,
    });
    client.join(`device:${data.deviceId}`);
    this.logger.log(`Admin ${client.data.userId} started live camera for ${data.deviceId}`);
  }

  @SubscribeMessage('admin:stop-live-camera')
  async handleStopLiveCamera(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) return;

    this.sendToDevice(data.deviceId, 'command', { command: 'STOP_LIVE_CAMERA' });
  }

  @SubscribeMessage('admin:switch-camera')
  async handleSwitchCamera(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) return;

    this.sendToDevice(data.deviceId, 'command', { command: 'SWITCH_CAMERA' });
  }

  // ─── Call Recording ────────────────────────────────────────────────────

  @SubscribeMessage('admin:enable-call-recording')
  async handleEnableCallRecording(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Access denied' });
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { command: 'ENABLE_CALL_RECORDING' });
    client.join(`device:${data.deviceId}`);
    this.logger.log(`Admin ${client.data.userId} enabled call recording for ${data.deviceId}`);
  }

  @SubscribeMessage('admin:disable-call-recording')
  async handleDisableCallRecording(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) return;

    this.sendToDevice(data.deviceId, 'command', { command: 'DISABLE_CALL_RECORDING' });
  }

  // ─── Keylogger ─────────────────────────────────────────────────────────

  @SubscribeMessage('admin:enable-keylogger')
  async handleEnableKeylogger(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) {
      client.emit('error', { message: 'Access denied' });
      return;
    }

    this.sendToDevice(data.deviceId, 'command', { command: 'ENABLE_KEYLOGGER' });
    client.join(`device:${data.deviceId}`);
    this.logger.log(`Admin ${client.data.userId} enabled keylogger for ${data.deviceId}`);
  }

  @SubscribeMessage('admin:disable-keylogger')
  async handleDisableKeylogger(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { deviceId: string },
  ) {
    if (client.data?.role !== 'ADMIN') return;

    const device = await this.prisma.device.findUnique({
      where: { id: data.deviceId },
      select: { managedByAdminId: true },
    });
    if (!device || device.managedByAdminId !== client.data.userId) return;

    this.sendToDevice(data.deviceId, 'command', { command: 'DISABLE_KEYLOGGER' });
  }

  // ─── Device Data Relay (audio, camera, call recordings, keylogs) ───────

  @SubscribeMessage('device:data')
  handleDeviceData(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { type: string; payload: unknown },
  ) {
    const deviceId = client.data?.deviceId;
    if (!deviceId) return;

    // Relay to all admins watching this device
    this.server.to(`device:${deviceId}`).except(client.id).emit(`admin:${data.type}`, {
      deviceId,
      ...data.payload as object,
      timestamp: new Date().toISOString(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════

  // ─── Public helpers for other modules ───────────────────────────────────

  /** Push a payload to a specific device socket, if connected. 
   *  Also queues command for polling when device is in background (Flutter dead).
   */
  sendToDevice(deviceId: string, event: string, data: unknown) {
    const socketId = this.connectedDevices.get(deviceId);
    if (socketId) {
      this.server.to(socketId).emit(event, data);
    }
    // Also queue for polling (in case Flutter is dead but native service is running)
    if (event === 'command' && typeof data === 'object' && data !== null) {
      const cmd = (data as any).command;
      if (cmd) {
        this.deviceService.queueCommand(deviceId, cmd, data);
      }
    }
  }

  /** Broadcast to every connected admin. */
  sendToAdmins(event: string, data: unknown) {
    this.server.to('admins').emit(event, data);
  }

  isDeviceOnline(deviceId: string): boolean {
    return this.connectedDevices.has(deviceId);
  }
}

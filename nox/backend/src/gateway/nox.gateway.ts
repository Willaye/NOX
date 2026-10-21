import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service.js';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  deviceId?: string;
}

/**
 * Commands a controller may send to a device via `device:command`.
 * Anything not listed is rejected before it reaches the device.
 */
export const ALLOWED_DEVICE_COMMANDS = new Set<string>([
  'ping',
  'ring',
  'locate',
  'lock',
  'sync',
  'refresh_status',
  'screenshot',
  'start_screen_mirror',
  'stop_screen_mirror',
  'start_file_transfer',
  'cancel_file_transfer',
]);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EVENT_TYPE_RE = /^[A-Za-z0-9_.:-]{1,64}$/;
const MAX_PAYLOAD_BYTES = 16 * 1024;

type WsError = { status: 'error'; message: string };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_RE.test(value);
}

function isFiniteInRange(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}

/** Optional payloads must be plain objects and small enough to relay safely. */
function isValidPayload(value: unknown): value is Record<string, unknown> | undefined {
  if (value === undefined) return true;
  if (!isPlainObject(value)) return false;
  try {
    return Buffer.byteLength(JSON.stringify(value), 'utf8') <= MAX_PAYLOAD_BYTES;
  } catch {
    return false; // circular / non-serializable
  }
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/nox',
})
export class NoxGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, Set<string>>(); // userId -> Set<socketId>
  private connectedDevices = new Map<string, string>(); // deviceId -> socketId

  constructor(
    private jwtService: JwtService,
    private prisma: PrismaService,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const rawToken =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');
      const token = typeof rawToken === 'string' ? rawToken : undefined;
      if (!token) {
        client.disconnect();
        return;
      }

      // Secret is configured on the GatewayModule's JwtModule (JWT_SECRET via ConfigService)
      const payload = this.jwtService.verify<{ sub?: unknown }>(token);
      if (typeof payload?.sub !== 'string') {
        client.disconnect();
        return;
      }

      client.userId = payload.sub;
      client.join(`user:${payload.sub}`);

      // Track connected user
      if (!this.connectedUsers.has(payload.sub)) {
        this.connectedUsers.set(payload.sub, new Set());
      }
      this.connectedUsers.get(payload.sub)!.add(client.id);

      client.emit('connected', { userId: payload.sub, socketId: client.id });
    } catch {
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.userId) {
      const sockets = this.connectedUsers.get(client.userId);
      if (sockets) {
        sockets.delete(client.id);
        if (sockets.size === 0) this.connectedUsers.delete(client.userId);
      }
    }

    if (client.deviceId) {
      this.connectedDevices.delete(client.deviceId);
      // Mark device offline
      await this.prisma.device.update({
        where: { id: client.deviceId },
        data: { isOnline: false },
      }).catch(() => {});

      // Notify user
      if (client.userId) {
        this.server.to(`user:${client.userId}`).emit('device:offline', {
          deviceId: client.deviceId,
          timestamp: new Date().toISOString(),
        });
      }
    }
  }

  @SubscribeMessage('device:register')
  async handleDeviceRegister(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: unknown,
  ) {
    if (!client.userId) return;
    if (!isPlainObject(data) || !isUuid(data.deviceId)) {
      return this.reject(client, 'Invalid payload: deviceId (UUID) is required');
    }
    const deviceId = data.deviceId;

    // Verify ownership
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId, deletedAt: null },
    });
    if (!device || device.ownerId !== client.userId) {
      client.emit('error', { message: 'Device not found or not yours' });
      return;
    }

    client.deviceId = deviceId;
    client.join(`device:${deviceId}`);
    this.connectedDevices.set(deviceId, client.id);

    // Mark device online
    await this.prisma.device.update({
      where: { id: deviceId },
      data: { isOnline: true, lastSeenAt: new Date() },
    });

    this.server.to(`user:${client.userId}`).emit('device:online', {
      deviceId: deviceId,
      timestamp: new Date().toISOString(),
    });

    return { status: 'registered', deviceId: deviceId };
  }

  @SubscribeMessage('device:heartbeat')
  async handleHeartbeat(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: unknown,
  ) {
    if (!client.deviceId || !client.userId) return;

    // Heartbeat body is optional; when present every field must be well-formed
    const body = data ?? {};
    if (!isPlainObject(body)) return this.reject(client, 'Invalid heartbeat payload');
    const { batteryLevel, networkType, latitude, longitude } = body;
    if (batteryLevel !== undefined && !(Number.isInteger(batteryLevel) && isFiniteInRange(batteryLevel, 0, 100))) {
      return this.reject(client, 'batteryLevel must be an integer between 0 and 100');
    }
    if (networkType !== undefined && !(typeof networkType === 'string' && networkType.length <= 32)) {
      return this.reject(client, 'networkType must be a string (max 32 chars)');
    }
    if (latitude !== undefined && !isFiniteInRange(latitude, -90, 90)) {
      return this.reject(client, 'latitude must be a number between -90 and 90');
    }
    if (longitude !== undefined && !isFiniteInRange(longitude, -180, 180)) {
      return this.reject(client, 'longitude must be a number between -180 and 180');
    }

    const updateData: Record<string, unknown> = { lastSeenAt: new Date(), isOnline: true };
    if (batteryLevel !== undefined) updateData.batteryLevel = batteryLevel;
    if (networkType) updateData.networkType = networkType;

    await this.prisma.device.update({
      where: { id: client.deviceId },
      data: updateData,
    });

    // Relay only validated fields — never spread arbitrary client data
    this.server.to(`user:${client.userId}`).emit('device:heartbeat', {
      deviceId: client.deviceId,
      batteryLevel,
      networkType,
      latitude,
      longitude,
      timestamp: new Date().toISOString(),
    });

    return { status: 'ok' };
  }

  @SubscribeMessage('device:command')
  async handleCommand(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: unknown,
  ) {
    if (!client.userId) return;
    if (!isPlainObject(data) || !isUuid(data.deviceId)) {
      return this.reject(client, 'Invalid payload: deviceId (UUID) is required');
    }
    if (typeof data.command !== 'string' || !ALLOWED_DEVICE_COMMANDS.has(data.command)) {
      return this.reject(client, 'Unknown or disallowed command');
    }
    if (!isValidPayload(data.payload)) {
      return this.reject(client, `payload must be an object no larger than ${MAX_PAYLOAD_BYTES} bytes`);
    }
    const { deviceId, command, payload } = data;

    // Verify ownership
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId, deletedAt: null },
    });
    if (!device || device.ownerId !== client.userId) {
      client.emit('error', { message: 'Device not found or not yours' });
      return;
    }

    // Forward command to device
    const deviceSocketId = this.connectedDevices.get(deviceId);
    if (deviceSocketId) {
      this.server.to(deviceSocketId).emit('command', {
        command: command,
        payload: payload,
        from: client.userId,
        timestamp: new Date().toISOString(),
      });
      return { status: 'sent' };
    }

    return { status: 'device_offline' };
  }

  @SubscribeMessage('device:event')
  async handleDeviceEvent(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: unknown,
  ) {
    if (!client.userId || !client.deviceId) return;
    if (!isPlainObject(data) || typeof data.type !== 'string' || !EVENT_TYPE_RE.test(data.type)) {
      return this.reject(client, 'Invalid payload: type must match [A-Za-z0-9_.:-]{1,64}');
    }
    if (!isValidPayload(data.payload)) {
      return this.reject(client, `payload must be an object no larger than ${MAX_PAYLOAD_BYTES} bytes`);
    }

    // Forward event to user's dashboard
    this.server.to(`user:${client.userId}`).emit('device:event', {
      deviceId: client.deviceId,
      type: data.type,
      payload: data.payload,
      timestamp: new Date().toISOString(),
    });

    return { status: 'ok' };
  }

  /** Emits an `error` event and returns an error ack for the client's callback. */
  private reject(client: AuthenticatedSocket, message: string): WsError {
    client.emit('error', { message });
    return { status: 'error', message };
  }

  // Utility: send notification to a specific user
  sendToUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  // Utility: send to a specific device
  sendToDevice(deviceId: string, event: string, data: unknown) {
    const socketId = this.connectedDevices.get(deviceId);
    if (socketId) {
      this.server.to(socketId).emit(event, data);
    }
  }

  isDeviceOnline(deviceId: string): boolean {
    return this.connectedDevices.has(deviceId);
  }

  getConnectedUserCount(): number {
    return this.connectedUsers.size;
  }

  getConnectedDeviceCount(): number {
    return this.connectedDevices.size;
  }
}

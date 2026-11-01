import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { CommandType, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { NoxGateway } from '../gateway/nox.gateway.js';
import { FcmService } from '../fcm/fcm.service.js';
import { DeviceQueryDto, EmployeeQueryDto } from './dto/admin.dto.js';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private prisma: PrismaService,
    private gateway: NoxGateway,
    private fcm: FcmService,
  ) {}

  // ─── Dashboard ────────────────────────────────────────────────────────

  async getDashboard(adminId: string) {
    // SECURITY FIX: Scope all counts to devices managed by this admin.
    // Previously, every admin saw global counts across all admins' fleets.
    const adminScope = { managedByAdminId: adminId };

    const [totalDevices, onlineDevices, totalEmployees, recentCommands] =
      await Promise.all([
        this.prisma.device.count({ where: adminScope }),
        this.prisma.device.count({ where: { ...adminScope, isOnline: true } }),
        // Count employees who have devices managed by this admin
        this.prisma.user.count({
          where: {
            role: 'EMPLOYEE',
            employeeDevice: { managedByAdminId: adminId },
          },
        }),
        this.prisma.deviceCommand.count({
          where: {
            createdAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
            device: { managedByAdminId: adminId },
          },
        }),
      ]);

    return {
      totalDevices,
      onlineDevices,
      offlineDevices: totalDevices - onlineDevices,
      totalEmployees,
      recentCommands,
    };
  }

  // ─── Devices list ─────────────────────────────────────────────────────

  async getAllDevices(adminId: string, query: DeviceQueryDto) {
    const limit = query.limit ?? 20;
    const page = query.page ?? 1;
    const skip = (page - 1) * limit;

    // SECURITY FIX: Scope to devices managed by this admin only.
    const where: any = { managedByAdminId: adminId };
    if (query.status === 'online') where.isOnline = true;
    else if (query.status === 'offline') where.isOnline = false;

    if (query.search) {
      // Search both device name and the employee email on the Device row
      // (fast — no join needed) and on the owner user as a fallback.
      where.AND = [
        { managedByAdminId: adminId },
        {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { employeeEmail: { contains: query.search, mode: 'insensitive' } },
            {
              owner: {
                email: { contains: query.search, mode: 'insensitive' },
              },
            },
          ],
        },
      ];
      delete where.managedByAdminId; // Moved into AND clause
    }

    const [devices, total] = await Promise.all([
      this.prisma.device.findMany({
        where,
        include: {
          owner: { select: { id: true, email: true, role: true } },
          employeeUser: { select: { id: true, email: true } },
        },
        orderBy: { createdAt: 'asc' },
        take: limit,
        skip,
      }),
      this.prisma.device.count({ where }),
    ]);

    return {
      devices: devices.map((d) => ({
        id: d.id,
        name: d.name,
        isOnline: d.isOnline,
        isPaired: d.isPaired,
        lockStatus: d.lockStatus,
        batteryLevel: d.batteryLevel,
        lastSeenAt: d.lastSeenAt,
        employeeEmail: d.employeeEmail ?? d.employeeUser?.email ?? null,
        owner: d.owner,
        createdAt: d.createdAt,
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ─── Device overview (lightweight) ────────────────────────────────────

  /**
   * Returns the device header + the single most recent sample from each
   * category. Admin UIs render the detail screen with this one call, then
   * fetch each category's full page via its dedicated endpoint.
   */
  async getDeviceOverview(deviceId: string, adminId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
      include: {
        owner: { select: { id: true, email: true, role: true } },
        employeeUser: { select: { id: true, email: true } },
      },
    });
    if (!device) throw new NotFoundException('Device not found');

    // SECURITY FIX: Verify this admin manages this device.
    if (device.managedByAdminId !== adminId) {
      throw new NotFoundException('Device not found');
    }

    const [
      latestLocation,
      latestUnlock,
      latestAppUsage,
      latestCall,
      latestBrowsing,
      latestGallery,
      pendingCommands,
      locationCount,
      unlockCount24h,
    ] = await Promise.all([
      this.prisma.locationLog.findFirst({
        where: { deviceId },
        orderBy: { timestamp: 'desc' },
      }),
      this.prisma.unlockEvent.findFirst({
        where: { deviceId },
        orderBy: { occurredAt: 'desc' },
      }),
      this.prisma.appUsage.findFirst({
        where: { deviceId },
        orderBy: { startedAt: 'desc' },
      }),
      this.prisma.callLog.findFirst({
        where: { deviceId },
        orderBy: { timestamp: 'desc' },
      }),
      this.prisma.browsingHistory.findFirst({
        where: { deviceId },
        orderBy: { visitedAt: 'desc' },
      }),
      this.prisma.galleryItem.findFirst({
        where: { deviceId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.deviceCommand.findMany({
        where: { deviceId, status: 'PENDING' },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      this.prisma.locationLog.count({ where: { deviceId } }),
      this.prisma.unlockEvent.count({
        where: {
          deviceId,
          occurredAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
        },
      }),
    ]);

    return {
      device: {
        id: device.id,
        name: device.name,
        isOnline: device.isOnline,
        isPaired: device.isPaired,
        lockStatus: device.lockStatus,
        batteryLevel: device.batteryLevel,
        lastSeenAt: device.lastSeenAt,
        deviceModel: device.deviceModel,
        osVersion: device.osVersion,
        appVersion: device.appVersion,
        employeeEmail:
          device.employeeEmail ?? device.employeeUser?.email ?? null,
        owner: device.owner,
        createdAt: device.createdAt,
        firstConnectedAt: device.firstConnectedAt,
      },
      latest: {
        location: latestLocation,
        unlock: latestUnlock,
        appUsage: latestAppUsage,
        call: latestCall,
        browsing: latestBrowsing,
        gallery: latestGallery,
      },
      stats: {
        locationCount,
        unlockCount24h,
      },
      pendingCommands,
    };
  }

  // ─── Lock / Unlock / Uninstall (wired to gateway) ─────────────────────

  async lockDevice(deviceId: string, adminId: string) {
    return this.issueCommand(deviceId, adminId, CommandType.LOCK);
  }

  async unlockDevice(deviceId: string, adminId: string) {
    return this.issueCommand(deviceId, adminId, CommandType.UNLOCK);
  }

  async requestUninstall(deviceId: string, adminId: string) {
    return this.issueCommand(deviceId, adminId, CommandType.UNINSTALL);
  }

  /**
   * Create the DeviceCommand row AND try to push the command to the device
   * right now via WebSocket (if connected). FCM is used as a wake-up fallback
   * for lock/uninstall so the agent gets the signal even if its socket is
   * dropped. Returns both the command row and whether delivery was attempted.
   */
  private async issueCommand(
    deviceId: string,
    adminId: string,
    command: CommandType,
  ) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
      include: { employeeUser: { select: { fcmToken: true } } },
    });
    if (!device) throw new NotFoundException('Device not found');

    // Update lock state optimistically so the admin UI reflects the new
    // state immediately. The device confirms via its next heartbeat.
    const lockUpdate =
      command === CommandType.LOCK
        ? { lockStatus: 'LOCKED' as const }
        : command === CommandType.UNLOCK
          ? { lockStatus: 'UNLOCKED' as const }
          : {};

    const [, cmd] = await this.prisma.$transaction([
      this.prisma.device.update({
        where: { id: deviceId },
        data: lockUpdate,
      }),
      this.prisma.deviceCommand.create({
        data: { deviceId, command, issuedBy: adminId },
      }),
    ]);

    // Live push via WS (if the device socket is connected)
    this.gateway.sendToDevice(deviceId, 'command', {
      commandId: cmd.id,
      command,
    });

    // FCM wake-up — only for commands that need urgency. For UNLOCK we skip
    // FCM to avoid draining battery; the agent can rely on next heartbeat.
    const token = device.employeeUser?.fcmToken;
    if (token && (command === CommandType.LOCK || command === CommandType.UNINSTALL)) {
      await this.fcm.sendToTokens([token], {
        title: 'NOX command',
        body: `New ${command.toLowerCase()} command`,
        data: { type: 'COMMAND', commandId: cmd.id, command },
        urgent: true,
      });
    }

    return { command: cmd, delivered: this.gateway.isDeviceOnline(deviceId) };
  }

  // ─── Legacy: direct Device/employee add (deprecated by /enroll/*) ─────

  /**
   * Kept for backwards compatibility with the old admin UI. Prefer the
   * enrollment flow for new integrations — this one creates an unpaired
   * device with no magic link / APK link, which the new mobile app can't
   * use.
   */
  async addDevice(email: string, adminId: string) {
    this.logger.warn(
      'POST /admin/devices/add is deprecated — use POST /enroll/invite instead',
    );
    const normalizedEmail = email.trim().toLowerCase();

    const user = await this.prisma.user.upsert({
      where: { email: normalizedEmail },
      update: {},
      create: { email: normalizedEmail, role: UserRole.EMPLOYEE },
    });

    const deviceCount = await this.prisma.device.count();
    const device = await this.prisma.device.create({
      data: {
        name: `Device ${deviceCount + 1}`,
        ownerId: user.id,
        // SECURITY FIX: Use the calling admin's id, not the employee's id.
        // Previously this was set to user.id which orphaned the device.
        managedByAdminId: adminId,
        employeeEmail: normalizedEmail,
        isPaired: false,
        isOnline: false,
      },
    });

    return {
      device: { id: device.id, name: device.name },
      user: { id: user.id, email: user.email },
      message:
        'Device record created but no invite was sent. Use POST /enroll/invite to send the install link.',
    };
  }

  // ─── Employees ────────────────────────────────────────────────────────

  async getAllEmployees(adminId: string, query: EmployeeQueryDto) {
    const limit = query.limit ?? 20;
    const page = query.page ?? 1;
    const skip = (page - 1) * limit;

    // SECURITY FIX: Only show employees whose device is managed by this admin.
    const where: any = {
      role: 'EMPLOYEE',
      employeeDevice: { managedByAdminId: adminId },
    };
    if (query.search) {
      where.OR = [
        { email: { contains: query.search, mode: 'insensitive' } },
        { firstName: { contains: query.search, mode: 'insensitive' } },
        { lastName: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const [employees, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          role: true,
          createdAt: true,
          _count: { select: { devices: true } },
          employeeDevice: {
            select: { id: true, name: true, isOnline: true, lastSeenAt: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip,
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      employees: employees.map((e) => ({
        id: e.id,
        email: e.email,
        firstName: e.firstName,
        lastName: e.lastName,
        role: e.role,
        device: e.employeeDevice,
        legacyDeviceCount: e._count.devices,
        createdAt: e.createdAt,
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getCommandHistory(deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    return this.prisma.deviceCommand.findMany({
      where: { deviceId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  // ─── Notifications ────────────────────────────────────────────────────

  async getNotifications(limit = 50) {
    return this.prisma.notification.findMany({
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async getUnreadCount() {
    return this.prisma.notification.count({ where: { isRead: false } });
  }

  async markNotificationRead(id: string) {
    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }

  async markAllRead() {
    return this.prisma.notification.updateMany({
      where: { isRead: false },
      data: { isRead: true },
    });
  }

  // ─── Admin FCM token registration ─────────────────────────────────────

  /**
   * Stash the admin device's FCM registration token on the admin User row so
   * tracking/offline/unlock events can push to them. One token per User —
   * if the admin reinstalls or switches devices we just overwrite.
   */
  async registerFcmToken(adminId: string, token: string) {
    if (!token || token.length < 10) {
      throw new BadRequestException('Invalid FCM token');
    }
    await this.prisma.user.update({
      where: { id: adminId },
      data: { fcmToken: token },
    });
    return { ok: true };
  }

  async clearFcmToken(adminId: string) {
    await this.prisma.user.update({
      where: { id: adminId },
      data: { fcmToken: null },
    });
    return { ok: true };
  }

  // ─── Remove Device ────────────────────────────────────────────────────

  async removeDevice(deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });
    if (!device) throw new NotFoundException('Device not found');

    await this.prisma.device.delete({ where: { id: deviceId } });

    return { message: `${device.name} removed successfully` };
  }
}

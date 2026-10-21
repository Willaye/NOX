import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service.js';
import { SignupDto, LoginDto } from './dto/auth.dto.js';
import { AuditService } from '../audit/audit.service.js';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private auditService: AuditService,
    private config: ConfigService,
  ) {}

  async signup(dto: SignupDto) {
    const email = normalizeEmail(dto.email);
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const userRole = await this.prisma.role.findUnique({ where: { name: 'USER' } });

    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          firstName: dto.firstName,
          lastName: dto.lastName,
          userRoles: userRole ? { create: { roleId: userRole.id } } : undefined,
        },
      });
    } catch (err) {
      // Unique constraint violation: a concurrent signup registered the same email first
      if (isPrismaUniqueViolation(err)) throw new ConflictException('Email already registered');
      throw err;
    }

    const tokens = await this.generateTokens(user.id, user.email);

    await this.auditService.log({
      actorId: user.id,
      action: 'auth.signup',
      resource: 'user',
      details: { email: user.email },
    });

    return {
      user: { id: user.id, email: user.email, firstName: user.firstName, lastName: user.lastName },
      ...tokens,
    };
  }

  async login(dto: LoginDto, ipAddress?: string) {
    const user = await this.prisma.user.findUnique({
      where: { email: normalizeEmail(dto.email), deletedAt: null },
      include: { userRoles: { include: { role: true } } },
    });
    if (!user || !user.isActive) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      await this.auditService.log({
        actorId: user.id,
        action: 'auth.login_failed',
        resource: 'user',
        ipAddress,
        result: 'FAILURE',
      });
      throw new UnauthorizedException('Invalid credentials');
    }

    const tokens = await this.generateTokens(user.id, user.email, dto.deviceInfo, ipAddress);

    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    await this.auditService.log({
      actorId: user.id,
      action: 'auth.login',
      resource: 'user',
      ipAddress,
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        roles: user.userRoles.map((ur: any) => ur.role.name),
      },
      ...tokens,
    };
  }

  async refreshTokens(refreshToken: string) {
    const stored = await this.prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Rotate: revoke old token
    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });

    const user = await this.prisma.user.findUnique({ where: { id: stored.userId } });
    if (!user || !user.isActive) throw new UnauthorizedException();

    return this.generateTokens(user.id, user.email);
  }

  async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      await this.prisma.refreshToken.updateMany({
        where: { userId, token: refreshToken },
        data: { revokedAt: new Date() },
      });
    } else {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    await this.auditService.log({ actorId: userId, action: 'auth.logout', resource: 'user' });
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        userRoles: { include: { role: true } },
        devices: { where: { deletedAt: null }, select: { id: true, name: true, deviceType: true, platform: true, isOnline: true, lastSeenAt: true } },
      },
    });
    if (!user) throw new UnauthorizedException();
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatarUrl: user.avatarUrl,
      emailVerified: user.emailVerified,
      roles: user.userRoles.map((ur: any) => ur.role.name),
      devices: user.devices,
      createdAt: user.createdAt,
    };
  }

  async getSessions(userId: string) {
    return this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      select: { id: true, deviceInfo: true, ipAddress: true, createdAt: true, expiresAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async revokeSession(userId: string, sessionId: string) {
    await this.prisma.refreshToken.updateMany({
      where: { id: sessionId, userId },
      data: { revokedAt: new Date() },
    });
  }

  private async generateTokens(userId: string, email: string, deviceInfo?: string, ipAddress?: string) {
    // Access-token expiry comes from JwtModule signOptions (JWT_EXPIRES_IN)
    const accessToken = this.jwtService.sign({ sub: userId, email });

    const refreshTokenValue = uuidv4();
    const refreshTtlMs = parseDurationMs(
      this.config.get<string>('REFRESH_TOKEN_EXPIRES_IN', '7d'),
      DEFAULT_REFRESH_TTL_MS,
    );
    const expiresAt = new Date(Date.now() + refreshTtlMs);

    await this.prisma.refreshToken.create({
      data: { token: refreshTokenValue, userId, deviceInfo, ipAddress, expiresAt },
    });

    return { accessToken, refreshToken: refreshTokenValue };
  }
}

const DEFAULT_REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const DURATION_UNITS_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
  w: 7 * 24 * 60 * 60 * 1000,
};

/**
 * Parses durations like "7d", "12h", "30m", "3600s", "2w".
 * A bare number is interpreted as days. Falls back to `fallbackMs` on invalid input.
 */
function parseDurationMs(value: string | undefined, fallbackMs: number): number {
  const match = /^\s*(\d+)\s*([smhdw]?)\s*$/i.exec(value ?? '');
  if (!match) return fallbackMs;
  const amount = parseInt(match[1], 10);
  const unit = (match[2] || 'd').toLowerCase();
  const ms = amount * DURATION_UNITS_MS[unit];
  return ms > 0 ? ms : fallbackMs;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function isPrismaUniqueViolation(err: unknown): boolean {
  return typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 'P2002';
}

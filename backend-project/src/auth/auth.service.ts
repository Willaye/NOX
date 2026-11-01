import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { MailService } from './mail.service.js';
import { SignupDto } from './dto/signup.dto.js';
import { LoginDto } from './dto/login.dto.js';
import {
  RequestMagicLinkDto,
  VerifyMagicLinkDto,
} from './dto/magic-link.dto.js';

const MAGIC_LINK_TTL_MS = 15 * 60 * 1000;

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private mailService: MailService,
  ) {}

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  async signup(dto: SignupDto) {
    const email = this.normalizeEmail(dto.email);

    // Check if user already exists (fast path; the unique constraint is the real guard)
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(dto.password, 12);

    // Create user — a concurrent signup can still race past the check above
    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          email,
          passwordHash,
        },
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        throw new ConflictException('Email already registered');
      }
      throw err;
    }

    // Generate token
    const token = this.generateToken(user.id, user.email, user.role);

    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
      accessToken: token,
    };
  }

  async login(dto: LoginDto) {
    // Find user
    const user = await this.prisma.user.findUnique({
      where: { email: this.normalizeEmail(dto.email) },
    });
    // Magic-link-only users have no password and cannot use password login
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Verify password
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Generate token
    const token = this.generateToken(user.id, user.email, user.role);

    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
      accessToken: token,
    };
  }

  async requestMagicLink(dto: RequestMagicLinkDto) {
    const email = this.normalizeEmail(dto.email);

    // SECURITY FIX: Only allow magic-link for EXISTING users. Previously this
    // would auto-create any email as ADMIN, allowing strangers to self-promote.
    // New admins must be created via a seed script or by an existing admin.
    // Employees are created via the /enroll flow (invite-based).
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Return the same generic message to avoid email enumeration attacks.
      // The caller cannot distinguish "user doesn't exist" from "email sent".
      return {
        message: 'If the email is valid, a sign-in code has been sent',
      };
    }

    // Invalidate any previous unused links so only the newest code works.
    // Avoids an attacker racing two concurrent requests to confuse the user.
    await this.prisma.magicLink.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    // Generate a 6-digit numeric OTP. Retry on the rare chance of a global
    // uniqueness collision in the MagicLink.token column.
    let token = '';
    let created = false;
    for (let attempt = 0; attempt < 8 && !created; attempt++) {
      token = (Math.floor(Math.random() * 1_000_000))
        .toString()
        .padStart(6, '0');
      try {
        await this.prisma.magicLink.create({
          data: {
            token,
            userId: user.id,
            expiresAt: new Date(Date.now() + MAGIC_LINK_TTL_MS),
          },
        });
        created = true;
      } catch (err) {
        if (
          err instanceof Prisma.PrismaClientKnownRequestError &&
          err.code === 'P2002'
        ) {
          // Collision — try another code.
          continue;
        }
        throw err;
      }
    }
    if (!created) {
      // Fall back to a longer code to guarantee uniqueness.
      token = randomBytes(4).toString('hex').toUpperCase();
      await this.prisma.magicLink.create({
        data: {
          token,
          userId: user.id,
          expiresAt: new Date(Date.now() + MAGIC_LINK_TTL_MS),
        },
      });
    }

    const sent = await this.mailService.sendMagicLink(user.email, token);

    // Expose the token in the response ONLY when DEV_EXPOSE_MAGIC_TOKEN is
    // "true" (local testing / email-less fallback). Keep it OFF in production
    // so the sign-in code is never leaked in the HTTP response.
    const exposeToken = process.env.DEV_EXPOSE_MAGIC_TOKEN === 'true';

    // Honest delivery state: if the email provider did not accept the message
    // and we are not exposing the token for testing, tell the client the code
    // could not be sent instead of pretending it was. The frontend surfaces
    // this so the user knows to use "Resend" rather than waiting forever.
    if (!sent && !exposeToken) {
      throw new ServiceUnavailableException(
        'We could not send your verification code right now. Please tap Resend in a few seconds.',
      );
    }

    return {
      message: 'If the email is valid, a sign-in code has been sent',
      ...(exposeToken ? { token } : {}),
    };
  }

  async verifyMagicLink(dto: VerifyMagicLinkDto) {
    const now = new Date();

    // Atomically claim the link: only succeeds if unused and unexpired,
    // so a token can't be redeemed twice by concurrent requests
    const claimed = await this.prisma.magicLink.updateMany({
      where: {
        token: dto.token,
        usedAt: null,
        expiresAt: { gt: now },
      },
      data: { usedAt: now },
    });
    if (claimed.count === 0) {
      throw new UnauthorizedException('Invalid or expired magic link');
    }

    const magicLink = await this.prisma.magicLink.findUnique({
      where: { token: dto.token },
      include: { user: true },
    });
    if (!magicLink) {
      throw new UnauthorizedException('Invalid or expired magic link');
    }

    const { user } = magicLink;

    // Generate token
    const token = this.generateToken(user.id, user.email, user.role);

    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
      accessToken: token,
    };
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        devices: {
          select: {
            id: true,
            name: true,
            isPaired: true,
            isOnline: true,
            lastSeenAt: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      hasPassword: !!user.passwordHash,
      devices: user.devices,
    };
  }

  async setPassword(userId: string, newPassword: string) {
    const passwordHash = await bcrypt.hash(newPassword, 12);
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
    };
  }

  private generateToken(userId: string, email: string, role: UserRole): string {
    return this.jwtService.sign({ sub: userId, email, role });
  }
}

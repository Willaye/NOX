import {
  Controller,
  Post,
  Get,
  Query,
  Body,
  HttpCode,
  HttpStatus,
  UseGuards,
  Request,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service.js';
import { SignupDto } from './dto/signup.dto.js';
import { LoginDto } from './dto/login.dto.js';
import {
  RequestMagicLinkDto,
  VerifyMagicLinkDto,
} from './dto/magic-link.dto.js';
import { SetPasswordDto } from './dto/set-password.dto.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('signup')
  signup(@Body() dto: SignupDto) {
    return this.authService.signup(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  // Tighter limit to curb email spam / mailbox flooding
  @Throttle({ default: { ttl: 60_000, limit: 5 } })
  @HttpCode(HttpStatus.OK)
  @Post('magic-link/request')
  requestMagicLink(@Body() dto: RequestMagicLinkDto) {
    return this.authService.requestMagicLink(dto);
  }

  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  @HttpCode(HttpStatus.OK)
  @Post('magic-link/verify')
  verifyMagicLink(@Body() dto: VerifyMagicLinkDto) {
    return this.authService.verifyMagicLink(dto);
  }

  /**
   * Browser-friendly magic-link endpoint. The sign-in email contains a GET
   * link to this URL; opening it in a browser consumes the token and shows
   * a confirmation page with the access token for the caller to copy.
   * Mobile apps continue to use POST /auth/magic-link/verify.
   */
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  @Get('verify')
  async verifyMagicLinkFromBrowser(
    @Query('token') token: string | undefined,
    @Res() res: Response,
  ) {
    const safeToken = (token ?? '').trim();
    if (!safeToken) {
      res.status(HttpStatus.BAD_REQUEST).type('html').send(
        renderAuthPage({
          ok: false,
          title: 'Missing token',
          body: 'The sign-in link is missing a token. Request a new one.',
        }),
      );
      return;
    }

    try {
      const result = await this.authService.verifyMagicLink({ token: safeToken });
      res.status(HttpStatus.OK).type('html').send(
        renderAuthPage({
          ok: true,
          title: 'Signed in',
          body: `Welcome, <b>${escapeHtml(result.user.email)}</b>. You can close this tab.`,
          accessToken: result.accessToken,
        }),
      );
    } catch (err: unknown) {
      const message =
        err && typeof err === 'object' && 'message' in err
          ? String((err as { message?: unknown }).message)
          : 'Invalid or expired sign-in link.';
      res.status(HttpStatus.UNAUTHORIZED).type('html').send(
        renderAuthPage({
          ok: false,
          title: 'Sign-in failed',
          body: escapeHtml(message),
        }),
      );
    }
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post('set-password')
  setPassword(@Request() req: any, @Body() dto: SetPasswordDto) {
    return this.authService.setPassword(req.user.id, dto.password);
  }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  getProfile(@Request() req: any) {
    return this.authService.getProfile(req.user.id);
  }
}

function escapeHtml(v: string): string {
  return v
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderAuthPage(opts: {
  ok: boolean;
  title: string;
  body: string;
  accessToken?: string;
}): string {
  const color = opts.ok ? '#00e5ff' : '#ff6b6b';
  const tokenBlock = opts.accessToken
    ? `
      <p style="margin:20px 0 8px;font-size:12px;color:#888;letter-spacing:1px;text-transform:uppercase">Access token</p>
      <textarea readonly onclick="this.select()" style="width:100%;height:120px;padding:12px;background:#0a0a1a;color:#00e5ff;border:1px solid #223;border-radius:8px;font-family:monospace;font-size:12px;word-break:break-all">${escapeHtml(
        opts.accessToken,
      )}</textarea>`
    : '';
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NOX — ${escapeHtml(
    opts.title,
  )}</title></head>
<body style="margin:0;background:#050505;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px">
  <div style="max-width:520px;width:100%;background:#111;border:1px solid #222;border-radius:16px;padding:32px">
    <div style="text-align:center;margin-bottom:24px">
      <span style="font-size:28px;font-weight:900;letter-spacing:6px;color:#fff">NOX</span>
      <div style="width:40px;height:3px;background:${color};border-radius:2px;margin:8px auto 0"></div>
    </div>
    <h1 style="margin:0 0 12px;font-size:22px;font-weight:700;color:${color};text-align:center">${escapeHtml(
      opts.title,
    )}</h1>
    <p style="margin:0;font-size:15px;color:#ccc;text-align:center;line-height:1.6">${opts.body}</p>
    ${tokenBlock}
  </div>
</body></html>`;
}

import { Controller, Post, Get, Body, UseGuards, HttpCode, HttpStatus, Ip } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { SignupDto, LoginDto, RefreshTokenDto, LogoutDto, RevokeSessionDto } from './dto/auth.dto.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('signup')
  signup(@Body() dto: SignupDto) {
    return this.authService.signup(dto);
  }

  @HttpCode(HttpStatus.OK)
  @Post('login')
  login(@Body() dto: LoginDto, @Ip() ip: string) {
    return this.authService.login(dto, ip);
  }

  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post('logout')
  logout(@CurrentUser('id') userId: string, @Body() dto: LogoutDto) {
    return this.authService.logout(userId, dto.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  getProfile(@CurrentUser('id') userId: string) {
    return this.authService.getProfile(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('sessions')
  getSessions(@CurrentUser('id') userId: string) {
    return this.authService.getSessions(userId);
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Post('sessions/revoke')
  revokeSession(@CurrentUser('id') userId: string, @Body() dto: RevokeSessionDto) {
    return this.authService.revokeSession(userId, dto.sessionId);
  }
}

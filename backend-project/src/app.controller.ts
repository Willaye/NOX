import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service.js';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  // NOTE: The dangerous unauthenticated DELETE /api/reset-all-data endpoint
  // has been removed. If you need to wipe tracking data, do so via a protected
  // admin endpoint or directly in the database.
}

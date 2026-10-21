import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  getStatus() {
    return {
      name: 'NOX API',
      version: '1.0.0',
      status: 'operational',
      tagline: 'Your Devices. Closer Than You Think.',
    };
  }
}

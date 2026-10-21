import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { FilesService } from './files.service.js';
import { CreateFileDto, RequestUploadUrlDto, ConfirmUploadDto } from './dto/files.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import { PaginationDto } from '../common/dto/pagination.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('files')
export class FilesController {
  constructor(private filesService: FilesService) {}

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateFileDto) {
    return this.filesService.createFileRecord(userId, dto);
  }

  @Post('upload-url')
  requestUploadUrl(@CurrentUser('id') userId: string, @Body() dto: RequestUploadUrlDto) {
    return this.filesService.requestUploadUrl(userId, dto);
  }

  @HttpCode(HttpStatus.OK)
  @Post('confirm-upload')
  confirmUpload(@CurrentUser('id') userId: string, @Body() dto: ConfirmUploadDto) {
    return this.filesService.confirmUpload(userId, dto);
  }

  @Get('device/:deviceId')
  getFilesByDevice(
    @CurrentUser('id') userId: string,
    @Param('deviceId') deviceId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.filesService.getFilesByDevice(userId, deviceId, {
      page: pagination.page,
      limit: pagination.limit,
    });
  }

  @Get(':id')
  getFileById(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.filesService.getFileById(userId, id);
  }

  @Get(':id/download-url')
  getDownloadUrl(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.filesService.getDownloadUrl(userId, id);
  }

  @Delete(':id')
  deleteFile(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.filesService.deleteFile(userId, id);
  }
}

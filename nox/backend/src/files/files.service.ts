import path from 'node:path';
import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateFileDto, RequestUploadUrlDto, ConfirmUploadDto } from './dto/files.dto.js';

@Injectable()
export class FilesService {
  constructor(private prisma: PrismaService) {}

  async createFileRecord(userId: string, dto: CreateFileDto) {
    // Verify device ownership
    const device = await this.prisma.device.findUnique({ where: { id: dto.deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    const storageKey = this.buildStorageKey(userId, dto.deviceId, dto.fileName);

    return this.prisma.file.create({
      data: {
        uploaderId: userId,
        deviceId: dto.deviceId,
        name: dto.fileName,
        originalName: dto.fileName,
        mimeType: dto.mimeType,
        size: BigInt(dto.fileSize),
        storagePath: dto.path || '/',
        storageKey,
      },
    });
  }

  async requestUploadUrl(userId: string, dto: RequestUploadUrlDto) {
    const device = await this.prisma.device.findUnique({ where: { id: dto.deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    const storageKey = this.buildStorageKey(userId, dto.deviceId, dto.fileName);

    const file = await this.prisma.file.create({
      data: {
        uploaderId: userId,
        deviceId: dto.deviceId,
        name: dto.fileName,
        originalName: dto.fileName,
        mimeType: dto.mimeType,
        size: BigInt(dto.fileSize),
        storagePath: '/',
        storageKey,
      },
    });

    // In production, generate a signed URL for S3/GCS upload
    // For now, return the file record with the storage key
    const uploadUrl = `/api/files/${file.id}/upload`;

    return {
      fileId: file.id,
      storageKey,
      uploadUrl,
      expiresIn: 3600,
    };
  }

  async confirmUpload(userId: string, dto: ConfirmUploadDto) {
    // The storage key is always server-generated in requestUploadUrl; never accept it from the client.
    const file = await this.prisma.file.findUnique({ where: { id: dto.fileId, deletedAt: null } });
    if (!file) throw new NotFoundException('File not found');
    if (file.uploaderId !== userId) throw new ForbiddenException('Not your file');

    return file;
  }

  async getFilesByDevice(userId: string, deviceId: string, params: { page?: number; limit?: number }) {
    const device = await this.prisma.device.findUnique({ where: { id: deviceId, deletedAt: null } });
    if (!device) throw new NotFoundException('Device not found');
    if (device.ownerId !== userId) throw new ForbiddenException('Not your device');

    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;

    const where = { deviceId, uploaderId: userId, deletedAt: null };

    const [data, total] = await Promise.all([
      this.prisma.file.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          originalName: true,
          mimeType: true,
          size: true,
          storagePath: true,
          createdAt: true,
        },
      }),
      this.prisma.file.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getFileById(userId: string, fileId: string) {
    const file = await this.prisma.file.findUnique({ where: { id: fileId, deletedAt: null } });
    if (!file) throw new NotFoundException('File not found');
    if (file.uploaderId !== userId) throw new ForbiddenException('Not your file');
    return file;
  }

  async getDownloadUrl(userId: string, fileId: string) {
    const file = await this.getFileById(userId, fileId);
    // In production, generate a signed download URL
    const downloadUrl = `/api/files/${file.id}/download`;
    return { fileId: file.id, downloadUrl, expiresIn: 3600 };
  }

  async deleteFile(userId: string, fileId: string) {
    await this.getFileById(userId, fileId);
    await this.prisma.file.update({ where: { id: fileId }, data: { deletedAt: new Date() } });
    return { message: 'File deleted' };
  }

  /** Builds a server-controlled storage key; the client-supplied name is reduced to a safe basename. */
  private buildStorageKey(userId: string, deviceId: string, fileName: string): string {
    return `${userId}/${deviceId}/${uuidv4()}/${sanitizeFileName(fileName)}`;
  }
}

/**
 * Strips directory components (both / and \ separators) and any character outside [A-Za-z0-9._-],
 * collapses dot runs (no "..") and caps length. Falls back to "file" if nothing safe remains.
 */
export function sanitizeFileName(fileName: string): string {
  const base = path.posix.basename(String(fileName).replace(/\\/g, '/'));
  const cleaned = base
    .normalize('NFKD')
    .replace(/[^A-Za-z0-9._-]/g, '_')
    .replace(/\.{2,}/g, '.')
    .replace(/^[.\-_]+/, '')
    .slice(0, 200);
  return cleaned || 'file';
}

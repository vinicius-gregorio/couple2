import { BadRequestException, Injectable } from '@nestjs/common';
import { DevicePlatform } from '@prisma/client';
import { PrismaService } from '../prisma';

export interface RegisterDeviceInput {
  token: string;
  platform: DevicePlatform;
  appVersion?: string;
  locale?: string;
}

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Upsert by token. A token that belonged to another account on the same
   * device is reassigned to the current user.
   */
  register(userId: string, input: RegisterDeviceInput) {
    const token = input.token.trim();
    if (!token) throw new BadRequestException('Token is required');
    const now = new Date();
    return this.prisma.deviceToken.upsert({
      where: { token },
      create: {
        userId,
        token,
        platform: input.platform,
        appVersion: input.appVersion,
        locale: input.locale,
        lastSeenAt: now,
      },
      update: {
        userId,
        platform: input.platform,
        appVersion: input.appVersion,
        locale: input.locale,
        lastSeenAt: now,
      },
    });
  }

  /** Removes the token only when it belongs to this user. */
  async remove(userId: string, token: string): Promise<void> {
    const value = token.trim();
    if (!value) throw new BadRequestException('Token is required');
    await this.prisma.deviceToken.deleteMany({
      where: { token: value, userId },
    });
  }
}

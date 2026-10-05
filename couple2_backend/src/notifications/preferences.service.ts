import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { isUniqueViolation } from './prisma-errors';

export interface PreferencePatch {
  pushEnabled?: boolean;
  lists?: boolean;
  importantDates?: boolean;
  dailyQuestion?: boolean;
  mood?: boolean;
  nudges?: boolean;
  datePlans?: boolean;
  quietStartMin?: number | null;
  quietEndMin?: number | null;
}

@Injectable()
export class NotificationPreferencesService {
  constructor(private readonly prisma: PrismaService) {}

  async getOrCreate(userId: string) {
    const existing = await this.prisma.notificationPreference.findUnique({
      where: { userId },
    });
    if (existing) return existing;

    try {
      return await this.prisma.notificationPreference.create({
        data: { userId },
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      return this.prisma.notificationPreference.findUniqueOrThrow({
        where: { userId },
      });
    }
  }

  async update(userId: string, patch: PreferencePatch) {
    await this.getOrCreate(userId);
    const data: Prisma.NotificationPreferenceUpdateInput = {};
    if (patch.pushEnabled !== undefined) data.pushEnabled = patch.pushEnabled;
    if (patch.lists !== undefined) data.lists = patch.lists;
    if (patch.importantDates !== undefined) {
      data.importantDates = patch.importantDates;
    }
    if (patch.dailyQuestion !== undefined) {
      data.dailyQuestion = patch.dailyQuestion;
    }
    if (patch.mood !== undefined) data.mood = patch.mood;
    if (patch.nudges !== undefined) data.nudges = patch.nudges;
    if (patch.datePlans !== undefined) data.datePlans = patch.datePlans;
    if (patch.quietStartMin !== undefined) {
      data.quietStartMin = patch.quietStartMin;
    }
    if (patch.quietEndMin !== undefined) data.quietEndMin = patch.quietEndMin;

    return this.prisma.notificationPreference.update({
      where: { userId },
      data,
    });
  }
}

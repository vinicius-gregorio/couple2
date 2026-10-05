import { ForbiddenException, Injectable } from '@nestjs/common';
import { ActivityType, MoodLevel } from '@prisma/client';
import { PAIRING_REQUIRED_MESSAGE } from '../auth/guards/pairing.guard';
import { ActivityService } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import {
  MOOD_HISTORY_DAY_MS,
  MOOD_HISTORY_DEFAULT_DAYS,
  MOOD_ROUTE,
  isMoodStale,
  pushesForMood,
} from './mood-policy';

export interface MoodActor {
  id: string;
  partnerId: string | null;
}

export interface MoodCouple {
  id: string;
}

export interface MoodSnapshot {
  mood: MoodLevel;
  note: string | null;
  createdAt: Date;
  stale: boolean;
}

export interface MoodCurrent {
  me: MoodSnapshot | null;
  partner: MoodSnapshot | null;
}

export interface MoodHistoryItem {
  id: string;
  userId: string;
  mood: MoodLevel;
  note: string | null;
  createdAt: Date;
}

@Injectable()
export class MoodService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  async create(
    user: MoodActor,
    couple: MoodCouple,
    input: { mood: MoodLevel; note?: string },
    now = new Date(),
  ): Promise<MoodHistoryItem> {
    this.partnerId(user);
    const created = await this.prisma.moodCheckin.create({
      data: {
        coupleId: couple.id,
        userId: user.id,
        mood: input.mood,
        note: input.note ?? null,
        createdAt: now,
      },
    });

    // The note stays on the check-in row. The feed and the push never see it.
    await this.activity.record({
      coupleId: couple.id,
      actorId: user.id,
      type: ActivityType.MOOD_SHARED,
      entity: { type: 'MoodCheckin', id: created.id },
      payload: { mood: created.mood },
      push: pushesForMood(created.mood) ? { route: MOOD_ROUTE } : undefined,
    });

    return this.toHistoryItem(created);
  }

  async current(
    user: MoodActor,
    couple: MoodCouple,
    now = new Date(),
  ): Promise<MoodCurrent> {
    const partnerId = this.partnerId(user);
    const [mine, partner] = await Promise.all([
      this.latest(couple.id, user.id),
      this.latest(couple.id, partnerId),
    ]);
    return {
      me: mine ? this.toSnapshot(mine, now) : null,
      partner: partner ? this.toSnapshot(partner, now) : null,
    };
  }

  async history(
    user: MoodActor,
    couple: MoodCouple,
    query: { days?: number },
    now = new Date(),
  ): Promise<{ days: number; items: MoodHistoryItem[] }> {
    this.partnerId(user);
    const days = query.days ?? MOOD_HISTORY_DEFAULT_DAYS;
    const since = new Date(now.getTime() - days * MOOD_HISTORY_DAY_MS);
    const rows = await this.prisma.moodCheckin.findMany({
      where: { coupleId: couple.id, createdAt: { gte: since } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    return { days, items: rows.map((row) => this.toHistoryItem(row)) };
  }

  private async latest(coupleId: string, userId: string) {
    return this.prisma.moodCheckin.findFirst({
      where: { coupleId, userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  private partnerId(user: MoodActor): string {
    if (!user.partnerId) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }
    return user.partnerId;
  }

  private toSnapshot(
    row: { mood: MoodLevel; note: string | null; createdAt: Date },
    now: Date,
  ): MoodSnapshot {
    return {
      mood: row.mood,
      note: row.note,
      createdAt: row.createdAt,
      stale: isMoodStale(row.createdAt, now),
    };
  }

  private toHistoryItem(row: {
    id: string;
    userId: string;
    mood: MoodLevel;
    note: string | null;
    createdAt: Date;
  }): MoodHistoryItem {
    return {
      id: row.id,
      userId: row.userId,
      mood: row.mood,
      note: row.note,
      createdAt: row.createdAt,
    };
  }
}

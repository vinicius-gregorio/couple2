import { Inject, Injectable, Logger } from '@nestjs/common';
import { ActivityType, DevicePlatform, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { CLOCK, type Clock } from './clock';
import { asRecord, truncateContent } from './json-record';
import { isQuietNow } from './local-time';
import { isUniqueViolation } from './prisma-errors';
import { buildPushCopy } from './push-copy';
import {
  DEFAULT_PUSH_PREFERENCES,
  LIST_ACTIVITY_TYPES,
  LIST_PUSH_WINDOW_MS,
  PushPreferenceFlags,
  categoryEnabled,
  pushCategoryFor,
  shouldDeliverPush,
} from './push-policy';
import {
  PUSH_SENDER,
  type PushSender,
  isInvalidTokenError,
} from './push-sender';

export interface ActivityEntityRef {
  type: string;
  id: string;
}

export interface PushSpec {
  /** Deep link opened when the notification is tapped. Example: `/lists/<id>`. */
  route: string;
  /**
   * When set, at most one push per this list per recipient per 5 minutes.
   * Later events in the window are feed-only.
   */
  listId?: string;
}

export interface RecordActivityInput {
  coupleId: string;
  /** Null is a system event (COUPLE_DATE_UPCOMING). The author never receives a push. */
  actorId: string | null;
  type: ActivityType;
  entity: ActivityEntityRef;
  payload?: Record<string, unknown>;
  push?: PushSpec;
}

/**
 * Inserts the feed row after the caller's transaction has committed, then
 * tries to push. A push failure is logged and never thrown.
 */
@Injectable()
export class ActivityService {
  private readonly logger = new Logger(ActivityService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(PUSH_SENDER) private readonly pushSender: PushSender,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async record(input: RecordActivityInput): Promise<{ id: string } | null> {
    try {
      return await this.persistAndNotify(input);
    } catch (error) {
      if (isUniqueViolation(error)) {
        this.logger.warn(
          `Skipped duplicate ${input.type} ${input.entity.type}:${input.entity.id}`,
        );
        return null;
      }
      this.logger.error(
        `Failed to record ${input.type} for couple ${input.coupleId}`,
        error instanceof Error ? error.stack : String(error),
      );
      throw error;
    }
  }

  private async persistAndNotify(
    input: RecordActivityInput,
  ): Promise<{ id: string } | null> {
    const couple = await this.prisma.couple.findUnique({
      where: { id: input.coupleId },
      select: {
        id: true,
        timezone: true,
        userAId: true,
        userBId: true,
        status: true,
      },
    });
    if (!couple || couple.status !== 'ACTIVE') {
      this.logger.warn(`Skip activity for inactive couple ${input.coupleId}`);
      return null;
    }

    const actorName = input.actorId
      ? await this.actorName(input.actorId)
      : null;
    const payload = this.snapshotPayload(input, actorName);

    const created = await this.prisma.activityEvent.create({
      data: {
        coupleId: input.coupleId,
        actorId: input.actorId,
        type: input.type,
        entityType: input.entity.type,
        entityId: input.entity.id,
        payload: payload as Prisma.InputJsonValue,
      },
    });

    if (input.push) {
      try {
        await this.dispatchPush(couple, created.id, input, payload, actorName);
      } catch (error) {
        this.logger.error(
          `Push failed for activity ${created.id}`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }

    return { id: created.id };
  }

  private snapshotPayload(
    input: RecordActivityInput,
    actorName: string | null,
  ): Record<string, unknown> {
    const payload: Record<string, unknown> = { ...(input.payload ?? {}) };
    if (typeof payload.content === 'string') {
      payload.content = truncateContent(payload.content);
    }
    if (actorName) payload.actorName = actorName;
    if (input.push?.route) payload.route = input.push.route;
    if (input.push?.listId && payload.listId == null) {
      payload.listId = input.push.listId;
    }
    return payload;
  }

  private async dispatchPush(
    couple: {
      id: string;
      timezone: string;
      userAId: string;
      userBId: string;
    },
    eventId: string,
    input: RecordActivityInput,
    payload: Record<string, unknown>,
    actorName: string | null,
  ): Promise<void> {
    const push = input.push;
    if (!push) return;

    const recipients = (
      input.actorId
        ? [couple.userAId, couple.userBId].filter((id) => id !== input.actorId)
        : [couple.userAId, couple.userBId]
    ).filter((id, index, all) => all.indexOf(id) === index);

    const category = pushCategoryFor(input.type);
    const now = this.clock.now();
    const pushed: string[] = [];
    const copy = buildPushCopy({
      type: input.type,
      actorName,
      payload,
    });

    for (const recipientId of recipients) {
      const prefs = await this.preferencesFor(recipientId);
      const quiet = isQuietNow(
        now,
        couple.timezone,
        prefs.quietStartMin,
        prefs.quietEndMin,
      );
      const spamBlocked = push.listId
        ? await this.recentListPush(couple.id, push.listId, recipientId, now)
        : false;

      if (
        !shouldDeliverPush({
          pushEnabled: prefs.pushEnabled,
          categoryEnabled: categoryEnabled(prefs, category),
          quiet,
          spamBlocked,
        })
      ) {
        continue;
      }

      const tokens = await this.prisma.deviceToken.findMany({
        where: {
          userId: recipientId,
          platform: { in: [DevicePlatform.IOS, DevicePlatform.ANDROID] },
        },
      });
      if (tokens.length === 0) continue;

      const results = await this.pushSender.send({
        tokens: tokens.map((row) => row.token),
        notification: copy,
        data: { type: input.type, route: push.route },
        collapseKey: `${input.entity.type}:${input.entity.id}`,
      });

      const invalid = results
        .filter(
          (result) => !result.success && isInvalidTokenError(result.errorCode),
        )
        .map((result) => result.token);
      if (invalid.length > 0) {
        await this.prisma.deviceToken.deleteMany({
          where: { token: { in: invalid } },
        });
      }

      if (results.some((result) => result.success)) {
        pushed.push(recipientId);
      }
    }

    if (pushed.length > 0) {
      await this.prisma.activityEvent.update({
        where: { id: eventId },
        data: {
          payload: {
            ...payload,
            pushedRecipientIds: pushed,
          } as Prisma.InputJsonValue,
        },
      });
    }
  }

  private async recentListPush(
    coupleId: string,
    listId: string,
    recipientId: string,
    now: Date,
  ): Promise<boolean> {
    const since = new Date(now.getTime() - LIST_PUSH_WINDOW_MS);
    const recent = await this.prisma.activityEvent.findMany({
      where: {
        coupleId,
        type: { in: LIST_ACTIVITY_TYPES },
        createdAt: { gt: since },
      },
      select: { payload: true },
    });
    return recent.some((row) => {
      const payload = asRecord(row.payload);
      if (!payload || payload.listId !== listId) return false;
      const ids = payload.pushedRecipientIds;
      return Array.isArray(ids) && ids.includes(recipientId);
    });
  }

  private async preferencesFor(userId: string): Promise<PushPreferenceFlags> {
    const row = await this.prisma.notificationPreference.findUnique({
      where: { userId },
    });
    if (!row) return { ...DEFAULT_PUSH_PREFERENCES };
    return {
      pushEnabled: row.pushEnabled,
      lists: row.lists,
      importantDates: row.importantDates,
      dailyQuestion: row.dailyQuestion,
      mood: row.mood,
      nudges: row.nudges,
      datePlans: row.datePlans,
      quietStartMin: row.quietStartMin,
      quietEndMin: row.quietEndMin,
    };
  }

  private async actorName(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });
    const trimmed = user?.name?.trim();
    return trimmed ? trimmed : 'Parceiro';
  }
}

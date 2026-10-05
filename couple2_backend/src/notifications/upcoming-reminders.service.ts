import { Injectable, Logger } from '@nestjs/common';
import {
  ActivityType,
  CoupleStatus,
  ListType,
  ListVisibility,
} from '@prisma/client';
import { Cron, CronExpression } from '@nestjs/schedule';
import { calendarDateToUtc } from '../common/calendar-date';
import { PrismaService } from '../prisma';
import { isUniqueViolation } from './prisma-errors';
import { ActivityService } from './activity.service';
import { giftReminderCopy, giftReminderOccasions } from './gift-reminder';
import { asRecord } from './json-record';
import { REMINDER_LOCAL_HOUR, isLocalHour } from './local-time';
import { reminderCandidates } from './reminder-candidates';

/**
 * Hourly job. Couples whose local time is 09:00 get COUPLE_DATE_UPCOMING
 * for dates that are 7, 1, or 0 days away. The same pass sends a private
 * GIFT_REMINDER at D-14 of the partner's birthday or the couple anniversary.
 * Re-running the same morning does not insert or push again.
 */
@Injectable()
export class UpcomingRemindersService {
  private readonly logger = new Logger(UpcomingRemindersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  @Cron(CronExpression.EVERY_HOUR, { name: 'couple-date-upcoming' })
  async handleCron(): Promise<void> {
    try {
      const result = await this.run(new Date());
      this.logger.log(
        `upcoming reminders checked=${result.checked} atLocalNine=${result.atLocalNine} recorded=${result.recorded} skipped=${result.skipped} giftReminders=${result.giftReminders}`,
      );
    } catch (error) {
      this.logger.error(
        'upcoming reminder job failed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  async run(now: Date): Promise<{
    checked: number;
    atLocalNine: number;
    recorded: number;
    skipped: number;
    giftReminders: number;
  }> {
    const couples = await this.prisma.couple.findMany({
      where: { status: CoupleStatus.ACTIVE },
      include: {
        dates: true,
        userA: { select: { id: true, name: true, birthDate: true } },
        userB: { select: { id: true, name: true, birthDate: true } },
      },
    });

    let atLocalNine = 0;
    let recorded = 0;
    let skipped = 0;
    let giftReminders = 0;

    for (const couple of couples) {
      let localNine = false;
      try {
        localNine = isLocalHour(now, couple.timezone, REMINDER_LOCAL_HOUR);
      } catch (error) {
        this.logger.error(
          `Invalid timezone for couple ${couple.id}`,
          error instanceof Error ? error.stack : String(error),
        );
        continue;
      }
      if (!localNine) continue;
      atLocalNine += 1;

      const candidates = reminderCandidates({
        coupleId: couple.id,
        timezone: couple.timezone,
        now,
        anniversaryDate: couple.anniversaryDate,
        birthdays: [
          {
            userId: couple.userA.id,
            name: couple.userA.name,
            birthDate: couple.userA.birthDate,
          },
          {
            userId: couple.userB.id,
            name: couple.userB.name,
            birthDate: couple.userB.birthDate,
          },
        ],
        dates: couple.dates.map((date) => ({
          id: date.id,
          title: date.title,
          date: date.date,
          recurrence: date.recurrence,
        })),
      });

      for (const candidate of candidates) {
        try {
          if (
            await this.alreadyRecorded(
              couple.id,
              candidate.entityId,
              candidate.occurrenceDate,
            )
          ) {
            skipped += 1;
            continue;
          }
          const saved = await this.activity.record({
            coupleId: couple.id,
            actorId: null,
            type: ActivityType.COUPLE_DATE_UPCOMING,
            entity: {
              type: candidate.entityType,
              id: candidate.entityId,
            },
            payload: {
              kind: candidate.kind,
              title: candidate.title,
              occurrenceDate: candidate.occurrenceDate,
              date: candidate.occurrenceDate,
              inDays: candidate.inDays,
            },
            push: { route: '/couple/dates' },
          });
          if (saved) recorded += 1;
          else skipped += 1;
        } catch (error) {
          skipped += 1;
          this.logger.error(
            `Reminder failed for couple ${couple.id} ${candidate.entityId}`,
            error instanceof Error ? error.stack : String(error),
          );
        }
      }

      try {
        giftReminders += await this.sendGiftReminders(couple, now);
      } catch (error) {
        this.logger.error(
          `Gift reminder failed for couple ${couple.id}`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }

    return {
      checked: couples.length,
      atLocalNine,
      recorded,
      skipped,
      giftReminders,
    };
  }

  /**
   * Push only. No ActivityEvent. The recipient is the owner who still has
   * undelivered ideas on a private gift list. The partner's own birthday
   * does not remind them.
   */
  private async sendGiftReminders(
    couple: {
      id: string;
      timezone: string;
      anniversaryDate: Date | null;
      userA: { id: string; name: string | null; birthDate: Date | null };
      userB: { id: string; name: string | null; birthDate: Date | null };
    },
    now: Date,
  ): Promise<number> {
    const occasions = giftReminderOccasions({
      timezone: couple.timezone,
      now,
      anniversaryDate: couple.anniversaryDate,
      birthdays: [couple.userA, couple.userB],
    });
    if (occasions.length === 0) return 0;

    const lists = await this.prisma.partnerList.findMany({
      where: {
        coupleId: couple.id,
        type: ListType.GIFT_IDEAS,
        visibility: ListVisibility.PRIVATE_FROM_PARTNER,
      },
      select: {
        ownerId: true,
        items: { select: { isCompleted: true } },
      },
    });
    const undelivered = new Map<string, number>();
    for (const list of lists) {
      const open = list.items.filter((item) => !item.isCompleted).length;
      if (open === 0) continue;
      undelivered.set(
        list.ownerId,
        (undelivered.get(list.ownerId) ?? 0) + open,
      );
    }

    let sent = 0;
    for (const member of [couple.userA, couple.userB]) {
      const ideaCount = undelivered.get(member.id) ?? 0;
      if (ideaCount === 0) continue;
      for (const occasion of occasions) {
        if (
          occasion.kind === 'birthday' &&
          occasion.subjectUserId === member.id
        ) {
          continue;
        }
        const claimed = await this.claimGiftReminder(
          member.id,
          couple.id,
          occasion.kind,
          occasion.occurrenceDate,
        );
        if (!claimed) continue;
        const copy = giftReminderCopy({
          kind: occasion.kind,
          displayName: occasion.displayName,
          ideaCount,
        });
        await this.activity.pushGiftReminder({
          coupleId: couple.id,
          recipientId: member.id,
          kind: occasion.kind,
          occurrenceDate: occasion.occurrenceDate,
          title: copy.title,
          body: copy.body,
        });
        sent += 1;
      }
    }
    return sent;
  }

  private async claimGiftReminder(
    userId: string,
    coupleId: string,
    kind: string,
    occurrenceDate: string,
  ): Promise<boolean> {
    try {
      await this.prisma.giftReminderDispatch.create({
        data: {
          userId,
          coupleId,
          kind,
          occurrenceDate: calendarDateToUtc(occurrenceDate),
        },
      });
      return true;
    } catch (error) {
      if (isUniqueViolation(error)) return false;
      throw error;
    }
  }

  private async alreadyRecorded(
    coupleId: string,
    entityId: string,
    occurrenceDate: string,
  ): Promise<boolean> {
    const rows = await this.prisma.activityEvent.findMany({
      where: {
        coupleId,
        type: ActivityType.COUPLE_DATE_UPCOMING,
        entityId,
      },
      select: { payload: true },
    });
    return rows.some((row) => {
      const payload = asRecord(row.payload);
      const date = payload?.occurrenceDate ?? payload?.date;
      return date === occurrenceDate;
    });
  }
}

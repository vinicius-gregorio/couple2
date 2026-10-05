import { Injectable, Logger } from '@nestjs/common';
import { ActivityType, CoupleStatus } from '@prisma/client';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma';
import { ActivityService } from './activity.service';
import { asRecord } from './json-record';
import { REMINDER_LOCAL_HOUR, isLocalHour } from './local-time';
import { reminderCandidates } from './reminder-candidates';

/**
 * Hourly job. Couples whose local time is 09:00 get COUPLE_DATE_UPCOMING
 * for dates that are 7, 1, or 0 days away. Re-running the same morning does
 * not insert or push again.
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
        `upcoming reminders checked=${result.checked} atLocalNine=${result.atLocalNine} recorded=${result.recorded} skipped=${result.skipped}`,
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
    }

    return { checked: couples.length, atLocalNine, recorded, skipped };
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

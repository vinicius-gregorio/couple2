import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CoupleStatus, DatePlanStatus } from '@prisma/client';
import { ActivityService } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import { reminderWindow } from './date-plan-policy';
import { datePlanReminderCopy } from './date-plan-time';

/**
 * Every 10 minutes on the scheduler from feature #2:
 * 1. ACCEPTED dates about 2 hours out get one push to both partners.
 * 2. PROPOSED dates whose time has passed become EXPIRED, with no push.
 */
@Injectable()
export class DatePlansScheduler {
  private readonly logger = new Logger(DatePlansScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES, { name: 'date-plans' })
  async handleCron(): Promise<void> {
    try {
      const result = await this.run(new Date());
      this.logger.log(
        `date plans reminded=${result.reminded} expired=${result.expired}`,
      );
    } catch (error) {
      this.logger.error(
        'date plan job failed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  async run(now: Date): Promise<{ reminded: number; expired: number }> {
    const reminded = await this.sendReminders(now);
    const expired = await this.expireProposed(now);
    return { reminded, expired };
  }

  private async sendReminders(now: Date): Promise<number> {
    const window = reminderWindow(now);
    const due = await this.prisma.datePlan.findMany({
      where: {
        status: DatePlanStatus.ACCEPTED,
        reminderSentAt: null,
        scheduledAt: { gte: window.from, lte: window.to },
        couple: { status: CoupleStatus.ACTIVE },
      },
      include: { couple: { select: { timezone: true } } },
    });

    let reminded = 0;
    for (const plan of due) {
      const claimed = await this.prisma.datePlan.updateMany({
        where: {
          id: plan.id,
          status: DatePlanStatus.ACCEPTED,
          reminderSentAt: null,
          scheduledAt: { gte: window.from, lte: window.to },
        },
        data: { reminderSentAt: now },
      });
      if (claimed.count === 0) continue;

      const copy = datePlanReminderCopy(
        plan.title,
        plan.scheduledAt,
        plan.couple.timezone,
      );
      try {
        await this.activity.pushDatePlanReminder({
          coupleId: plan.coupleId,
          datePlanId: plan.id,
          title: copy.title,
          body: copy.body,
        });
        reminded += 1;
      } catch (error) {
        await this.prisma.datePlan.updateMany({
          where: { id: plan.id, reminderSentAt: now },
          data: { reminderSentAt: null },
        });
        this.logger.error(
          `Date reminder failed for ${plan.id}`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }
    return reminded;
  }

  private async expireProposed(now: Date): Promise<number> {
    const result = await this.prisma.datePlan.updateMany({
      where: {
        status: DatePlanStatus.PROPOSED,
        scheduledAt: { lt: now },
      },
      data: { status: DatePlanStatus.EXPIRED },
    });
    return result.count;
  }
}

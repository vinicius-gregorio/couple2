import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CoupleStatus } from '@prisma/client';
import { PrismaService } from '../prisma';
import {
  DAILY_QUESTION_LOCAL_HOUR,
  isLocalHour,
} from '../notifications/local-time';
import { QuestionsService } from './questions.service';

/**
 * Reuses the hourly scheduler from feature #2. At 10:00 in the couple
 * timezone, creates today's CoupleQuestion (same path as lazy-assign) and
 * sends the dailyQuestion push. A couple with no device still gets the row.
 */
@Injectable()
export class DailyQuestionScheduler {
  private readonly logger = new Logger(DailyQuestionScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly questions: QuestionsService,
  ) {}

  @Cron(CronExpression.EVERY_HOUR, { name: 'daily-question' })
  async handleCron(): Promise<void> {
    try {
      const result = await this.run(new Date());
      this.logger.log(
        `daily question checked=${result.checked} atLocalTen=${result.atLocalTen} pushed=${result.pushed} skipped=${result.skipped}`,
      );
    } catch (error) {
      this.logger.error(
        'daily question job failed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  async run(now: Date): Promise<{
    checked: number;
    atLocalTen: number;
    pushed: number;
    skipped: number;
  }> {
    const couples = await this.prisma.couple.findMany({
      where: { status: CoupleStatus.ACTIVE },
      select: { id: true, timezone: true },
    });

    let atLocalTen = 0;
    let pushed = 0;
    let skipped = 0;

    for (const couple of couples) {
      let localTen = false;
      try {
        localTen = isLocalHour(now, couple.timezone, DAILY_QUESTION_LOCAL_HOUR);
      } catch (error) {
        skipped += 1;
        this.logger.error(
          `Invalid timezone for couple ${couple.id}`,
          error instanceof Error ? error.stack : String(error),
        );
        continue;
      }
      if (!localTen) continue;
      atLocalTen += 1;

      try {
        const result = await this.questions.deliverDailyQuestion(couple, now);
        if (result.pushed) pushed += 1;
        else skipped += 1;
      } catch (error) {
        skipped += 1;
        this.logger.error(
          `Daily question failed for couple ${couple.id}`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }

    return { checked: couples.length, atLocalTen, pushed, skipped };
  }
}

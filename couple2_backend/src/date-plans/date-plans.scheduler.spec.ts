/* eslint-disable @typescript-eslint/require-await */
import { DatePlanStatus } from '@prisma/client';
import { ActivityService } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import { DatePlansScheduler } from './date-plans.scheduler';

describe('DatePlansScheduler', () => {
  const now = new Date('2026-10-05T15:00:00.000Z');
  const scheduledAt = new Date('2026-10-05T17:00:00.000Z');

  function harness(claimCounts: number[]) {
    const pushes: Array<{
      coupleId: string;
      datePlanId: string;
      body: string;
    }> = [];
    let claims = 0;
    const expireWhere: unknown[] = [];
    const prisma = {
      datePlan: {
        findMany: async () => [
          {
            id: 'plan-1',
            coupleId: 'couple-1',
            title: 'Japonês',
            scheduledAt,
            status: DatePlanStatus.ACCEPTED,
            reminderSentAt: null,
            couple: { timezone: 'America/Sao_Paulo' },
          },
        ],
        updateMany: async (args: {
          where: { status?: string };
          data: object;
        }) => {
          if (args.where.status === DatePlanStatus.PROPOSED) {
            expireWhere.push(args.where);
            return { count: 2 };
          }
          if (
            'reminderSentAt' in args.data &&
            args.data.reminderSentAt === null
          ) {
            return { count: 1 };
          }
          const count = claimCounts[claims] ?? 0;
          claims += 1;
          return { count };
        },
      },
    } as unknown as PrismaService;
    const activity = {
      pushDatePlanReminder: async (input: {
        coupleId: string;
        datePlanId: string;
        body: string;
      }) => {
        pushes.push(input);
      },
    } as unknown as ActivityService;
    return {
      scheduler: new DatePlansScheduler(prisma, activity),
      pushes,
      expireWhere,
    };
  }

  it('sends one reminder and does not send again when the claim is taken', async () => {
    const { scheduler, pushes } = harness([1, 0]);

    const first = await scheduler.run(now);
    const second = await scheduler.run(now);

    expect(first.reminded).toBe(1);
    expect(second.reminded).toBe(0);
    expect(pushes).toHaveLength(1);
    expect(pushes[0]).toMatchObject({
      coupleId: 'couple-1',
      datePlanId: 'plan-1',
    });
    // 17:00 UTC is 14:00 in America/Sao_Paulo. The push must not say 17:00.
    expect(pushes[0].body).toContain('14:00');
    expect(pushes[0].body).not.toContain('17:00');
  });

  it('expires overdue proposals without a push', async () => {
    const { scheduler, pushes, expireWhere } = harness([0]);
    const result = await scheduler.run(now);
    expect(result.expired).toBe(2);
    expect(expireWhere).toEqual([
      {
        status: DatePlanStatus.PROPOSED,
        scheduledAt: { lt: now },
      },
    ]);
    expect(pushes).toHaveLength(0);
  });
});

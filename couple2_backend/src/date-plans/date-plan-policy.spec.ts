import { DatePlanStatus } from '@prisma/client';
import {
  buildDatePlanListWhere,
  canMarkDone,
  datePlanScope,
  reminderWindow,
} from './date-plan-policy';

const now = new Date('2026-10-05T15:00:00.000Z');

describe('date plan scope', () => {
  it('keeps a live date in upcoming until 2 hours after it starts', () => {
    const soon = new Date(now.getTime() + 3 * 60 * 60 * 1000);
    const justOver = new Date(now.getTime() - 90 * 60 * 1000);
    const tooOld = new Date(now.getTime() - 3 * 60 * 60 * 1000);

    expect(datePlanScope(DatePlanStatus.PROPOSED, soon, now)).toBe('upcoming');
    expect(datePlanScope(DatePlanStatus.ACCEPTED, justOver, now)).toBe(
      'upcoming',
    );
    expect(datePlanScope(DatePlanStatus.PROPOSED, tooOld, now)).toBe('past');
  });

  it('puts EXPIRED, DECLINED, CANCELLED and DONE in past', () => {
    const future = new Date(now.getTime() + 60 * 60 * 1000);
    for (const status of [
      DatePlanStatus.EXPIRED,
      DatePlanStatus.DECLINED,
      DatePlanStatus.CANCELLED,
      DatePlanStatus.DONE,
    ]) {
      expect(datePlanScope(status, future, now)).toBe('past');
    }
  });

  it('queries past as the complement of the upcoming filter', () => {
    const where = buildDatePlanListWhere('couple-1', 'past', now, null);
    expect(where).toEqual({
      coupleId: 'couple-1',
      NOT: {
        AND: [
          {
            status: {
              in: [DatePlanStatus.PROPOSED, DatePlanStatus.ACCEPTED],
            },
          },
          {
            scheduledAt: { gte: new Date(now.getTime() - 2 * 60 * 60 * 1000) },
          },
        ],
      },
    });
  });
});

describe('date plan time windows', () => {
  it('allows done from 2 hours before the start', () => {
    const early = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const within = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    const started = new Date(now.getTime() - 60 * 1000);
    expect(canMarkDone(early, now)).toBe(false);
    expect(canMarkDone(within, now)).toBe(true);
    expect(canMarkDone(started, now)).toBe(true);
  });

  it('opens the reminder window at now+1h50 through now+2h10', () => {
    const window = reminderWindow(now);
    expect(window.from.toISOString()).toBe('2026-10-05T16:50:00.000Z');
    expect(window.to.toISOString()).toBe('2026-10-05T17:10:00.000Z');
  });
});

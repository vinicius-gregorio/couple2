import { DatePlanStatus, ListType, Prisma } from '@prisma/client';

export const DATE_PLAN_TITLE_MAX = 80;
export const DATE_PLAN_DESCRIPTION_MAX = 500;
export const DATE_PLAN_LOCATION_MAX = 120;
export const DATE_PLAN_NOTE_MAX = 140;
export const DATE_PLAN_PAGE_DEFAULT = 20;

/** PROPOSED/ACCEPTED stay in "upcoming" until 2 hours after scheduledAt. */
export const UPCOMING_GRACE_MS = 2 * 60 * 60 * 1000;

/** done is allowed once scheduledAt is at most this far in the future. */
export const DONE_LEAD_MS = 2 * 60 * 60 * 1000;

/** Reminder fires about 2 hours before an ACCEPTED date. */
export const REMINDER_LEAD_MS = 2 * 60 * 60 * 1000;

/** The 10-minute job looks 10 minutes to either side of the 2-hour mark. */
export const REMINDER_SLACK_MS = 10 * 60 * 1000;

export const DATE_PLAN_LIST_TYPES: ListType[] = [
  ListType.MOVIES,
  ListType.TRAVEL,
];

const LIVE_STATUSES: DatePlanStatus[] = [
  DatePlanStatus.PROPOSED,
  DatePlanStatus.ACCEPTED,
];

export type DatePlanScope = 'upcoming' | 'past';

export function upcomingCutoff(now: Date): Date {
  return new Date(now.getTime() - UPCOMING_GRACE_MS);
}

export function doneDeadline(now: Date): Date {
  return new Date(now.getTime() + DONE_LEAD_MS);
}

export function reminderWindow(now: Date): { from: Date; to: Date } {
  return {
    from: new Date(now.getTime() + REMINDER_LEAD_MS - REMINDER_SLACK_MS),
    to: new Date(now.getTime() + REMINDER_LEAD_MS + REMINDER_SLACK_MS),
  };
}

/**
 * upcoming = PROPOSED or ACCEPTED with scheduledAt >= now-2h, oldest first.
 * past = everything else, newest first.
 */
export function datePlanScope(
  status: DatePlanStatus,
  scheduledAt: Date,
  now: Date,
): DatePlanScope {
  const live = LIVE_STATUSES.includes(status);
  if (live && scheduledAt.getTime() >= upcomingCutoff(now).getTime()) {
    return 'upcoming';
  }
  return 'past';
}

export function canMarkDone(scheduledAt: Date, now: Date): boolean {
  return scheduledAt.getTime() <= doneDeadline(now).getTime();
}

export interface DatePlanCursor {
  scheduledAt: Date;
  id: string;
}

export function buildDatePlanListWhere(
  coupleId: string,
  scope: DatePlanScope,
  now: Date,
  cursor: DatePlanCursor | null,
): Prisma.DatePlanWhereInput {
  const cutoff = upcomingCutoff(now);
  const scopeWhere: Prisma.DatePlanWhereInput =
    scope === 'upcoming'
      ? {
          coupleId,
          status: { in: LIVE_STATUSES },
          scheduledAt: { gte: cutoff },
        }
      : {
          coupleId,
          NOT: {
            AND: [
              { status: { in: LIVE_STATUSES } },
              { scheduledAt: { gte: cutoff } },
            ],
          },
        };

  if (!cursor) return scopeWhere;

  const cursorWhere: Prisma.DatePlanWhereInput =
    scope === 'upcoming'
      ? {
          OR: [
            { scheduledAt: { gt: cursor.scheduledAt } },
            {
              AND: [
                { scheduledAt: cursor.scheduledAt },
                { id: { gt: cursor.id } },
              ],
            },
          ],
        }
      : {
          OR: [
            { scheduledAt: { lt: cursor.scheduledAt } },
            {
              AND: [
                { scheduledAt: cursor.scheduledAt },
                { id: { lt: cursor.id } },
              ],
            },
          ],
        };

  return { AND: [scopeWhere, cursorWhere] };
}

export function datePlanOrder(
  scope: DatePlanScope,
): Prisma.DatePlanOrderByWithRelationInput[] {
  return scope === 'upcoming'
    ? [{ scheduledAt: 'asc' }, { id: 'asc' }]
    : [{ scheduledAt: 'desc' }, { id: 'desc' }];
}

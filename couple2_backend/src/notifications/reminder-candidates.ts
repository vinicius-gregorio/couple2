import {
  calendarYmdInTimeZone,
  diffCalendarDays,
  nextYearlyOnOrAfter,
} from '../couple/couple-calendar';
import { toDateOnlyString } from '../common/calendar-date';

export const REMINDER_OFFSETS = new Set([0, 1, 7]);

export type ReminderKind = 'anniversary' | 'birthday' | 'custom';

export interface ReminderCandidate {
  kind: ReminderKind;
  title: string;
  entityType: 'Couple' | 'User' | 'CoupleDate';
  entityId: string;
  occurrenceDate: string;
  inDays: number;
}

export function reminderCandidates(input: {
  coupleId: string;
  timezone: string;
  now: Date;
  anniversaryDate: Date | null;
  birthdays: { userId: string; name: string | null; birthDate: Date | null }[];
  dates: {
    id: string;
    title: string;
    date: Date;
    recurrence: 'NONE' | 'YEARLY';
  }[];
}): ReminderCandidate[] {
  const today = calendarYmdInTimeZone(input.now, input.timezone);
  const found: ReminderCandidate[] = [];

  const consider = (
    occurrence: string,
    candidate: Omit<ReminderCandidate, 'occurrenceDate' | 'inDays'>,
  ) => {
    const inDays = diffCalendarDays(today, occurrence);
    if (!REMINDER_OFFSETS.has(inDays)) return;
    found.push({ ...candidate, occurrenceDate: occurrence, inDays });
  };

  if (input.anniversaryDate) {
    const { month, day } = monthDay(input.anniversaryDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'anniversary',
      title: 'Aniversário de namoro',
      entityType: 'Couple',
      entityId: input.coupleId,
    });
  }

  for (const birthday of input.birthdays) {
    if (!birthday.birthDate) continue;
    const { month, day } = monthDay(birthday.birthDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'birthday',
      title: `Aniversário de ${displayName(birthday.name)}`,
      entityType: 'User',
      entityId: birthday.userId,
    });
  }

  for (const date of input.dates) {
    if (date.recurrence === 'NONE') {
      const ymd = toDateOnlyString(date.date);
      if (!ymd) continue;
      consider(ymd, {
        kind: 'custom',
        title: date.title,
        entityType: 'CoupleDate',
        entityId: date.id,
      });
      continue;
    }
    const { month, day } = monthDay(date.date);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'custom',
      title: date.title,
      entityType: 'CoupleDate',
      entityId: date.id,
    });
  }

  return found;
}

function monthDay(date: Date): { month: number; day: number } {
  return { month: date.getUTCMonth() + 1, day: date.getUTCDate() };
}

function displayName(name: string | null): string {
  const trimmed = name?.trim();
  return trimmed ? trimmed : 'Parceiro';
}

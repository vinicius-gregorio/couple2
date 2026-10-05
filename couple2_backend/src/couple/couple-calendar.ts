import { formatInTimeZone } from 'date-fns-tz';
import { toDateOnlyString } from '../common/calendar-date';

export const UPCOMING_WINDOW_DAYS = 60;

export type UpcomingKind = 'anniversary' | 'birthday' | 'custom';

export interface UpcomingEntry {
  kind: UpcomingKind;
  title: string;
  /** Occurrence inside the window. Feb 29 becomes Feb 28 in non-leap years. */
  date: string;
  inDays: number;
  coupleDateId: string | null;
}

export function calendarYmdInTimeZone(instant: Date, timeZone: string): string {
  return formatInTimeZone(instant, timeZone, 'yyyy-MM-dd');
}

export function diffCalendarDays(fromYmd: string, toYmd: string): number {
  const [y1, m1, d1] = fromYmd.split('-').map(Number);
  const [y2, m2, d2] = toYmd.split('-').map(Number);
  const start = Date.UTC(y1, m1 - 1, d1);
  const end = Date.UTC(y2, m2 - 1, d2);
  return Math.round((end - start) / 86_400_000);
}

function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

/** Yearly occurrence of month/day in `year`. Feb 29 clamps to Feb 28 when needed. */
export function yearlyOccurrenceYmd(
  year: number,
  month: number,
  day: number,
): string {
  let resolvedDay = day;
  if (month === 2 && day === 29 && !isLeapYear(year)) {
    resolvedDay = 28;
  }
  const monthText = String(month).padStart(2, '0');
  const dayText = String(resolvedDay).padStart(2, '0');
  return `${year}-${monthText}-${dayText}`;
}

export function nextYearlyOnOrAfter(
  month: number,
  day: number,
  todayYmd: string,
): string {
  const year = Number(todayYmd.slice(0, 4));
  const thisYear = yearlyOccurrenceYmd(year, month, day);
  if (thisYear >= todayYmd) return thisYear;
  return yearlyOccurrenceYmd(year + 1, month, day);
}

function monthDay(date: Date): { month: number; day: number } {
  return { month: date.getUTCMonth() + 1, day: date.getUTCDate() };
}

/**
 * Whole calendar days from the relationship start through today in the couple
 * timezone, counting the first day as 1.
 * Start is anniversaryDate when set, otherwise the calendar day of pairedAt.
 */
export function daysTogether(input: {
  anniversaryDate: Date | null;
  pairedAt: Date;
  timezone: string;
  now?: Date;
}): number {
  const now = input.now ?? new Date();
  const today = calendarYmdInTimeZone(now, input.timezone);
  const start = input.anniversaryDate
    ? (toDateOnlyString(input.anniversaryDate) as string)
    : calendarYmdInTimeZone(input.pairedAt, input.timezone);
  return diffCalendarDays(start, today) + 1;
}

export function buildUpcoming(input: {
  timezone: string;
  now?: Date;
  anniversaryDate: Date | null;
  birthdays: { name: string; birthDate: Date | null }[];
  dates: {
    id: string;
    title: string;
    date: Date;
    recurrence: 'NONE' | 'YEARLY';
  }[];
}): UpcomingEntry[] {
  const today = calendarYmdInTimeZone(input.now ?? new Date(), input.timezone);
  const entries: UpcomingEntry[] = [];

  const consider = (
    occurrence: string,
    entry: Omit<UpcomingEntry, 'date' | 'inDays'>,
  ) => {
    const inDays = diffCalendarDays(today, occurrence);
    if (inDays < 0 || inDays > UPCOMING_WINDOW_DAYS) return;
    entries.push({ ...entry, date: occurrence, inDays });
  };

  if (input.anniversaryDate) {
    const { month, day } = monthDay(input.anniversaryDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'anniversary',
      title: 'Aniversário de namoro',
      coupleDateId: null,
    });
  }

  for (const birthday of input.birthdays) {
    if (!birthday.birthDate) continue;
    const { month, day } = monthDay(birthday.birthDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'birthday',
      title: birthday.name,
      coupleDateId: null,
    });
  }

  for (const date of input.dates) {
    const ymd = toDateOnlyString(date.date) as string;
    if (date.recurrence === 'NONE') {
      consider(ymd, {
        kind: 'custom',
        title: date.title,
        coupleDateId: date.id,
      });
      continue;
    }
    const { month, day } = monthDay(date.date);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'custom',
      title: date.title,
      coupleDateId: date.id,
    });
  }

  const kindOrder: Record<UpcomingKind, number> = {
    anniversary: 0,
    birthday: 1,
    custom: 2,
  };

  entries.sort((a, b) => {
    if (a.inDays !== b.inDays) return a.inDays - b.inDays;
    if (kindOrder[a.kind] !== kindOrder[b.kind]) {
      return kindOrder[a.kind] - kindOrder[b.kind];
    }
    return a.title.localeCompare(b.title);
  });

  return entries;
}

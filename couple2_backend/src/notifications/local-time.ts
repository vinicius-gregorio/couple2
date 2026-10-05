import { formatInTimeZone } from 'date-fns-tz';

export const REMINDER_LOCAL_HOUR = 9;

/** Local hour when today's question is created and the dailyQuestion push goes out. */
export const DAILY_QUESTION_LOCAL_HOUR = 10;

export function isLocalHour(
  now: Date,
  timeZone: string,
  hour: number,
): boolean {
  return Number(formatInTimeZone(now, timeZone, 'H')) === hour;
}

export function localMinutesOfDay(now: Date, timeZone: string): number {
  const hours = Number(formatInTimeZone(now, timeZone, 'H'));
  const minutes = Number(formatInTimeZone(now, timeZone, 'm'));
  return hours * 60 + minutes;
}

/**
 * Quiet window in minutes from local midnight. A window that passes midnight
 * (23:00–07:00) wraps. The end minute is exclusive, so 07:00 is already quiet-free.
 * Missing either bound, or a zero-length window, means no quiet hours.
 */
export function isQuietNow(
  now: Date,
  timeZone: string,
  quietStartMin: number | null | undefined,
  quietEndMin: number | null | undefined,
): boolean {
  if (quietStartMin == null || quietEndMin == null) return false;
  if (quietStartMin === quietEndMin) return false;
  const minute = localMinutesOfDay(now, timeZone);
  if (quietStartMin < quietEndMin) {
    return minute >= quietStartMin && minute < quietEndMin;
  }
  return minute >= quietStartMin || minute < quietEndMin;
}

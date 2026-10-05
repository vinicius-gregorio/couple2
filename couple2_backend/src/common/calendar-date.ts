/** Calendar dates are stored as UTC midnight (@db.Date). Never shift them through a local zone. */

const DATE_ONLY = /^(\d{4})-(\d{2})-(\d{2})$/;

export function parseCalendarDate(value: string): Date | null {
  const match = DATE_ONLY.exec(value);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const utc = new Date(Date.UTC(year, month - 1, day));
  if (
    utc.getUTCFullYear() !== year ||
    utc.getUTCMonth() !== month - 1 ||
    utc.getUTCDate() !== day
  ) {
    return null;
  }
  return utc;
}

export function calendarDateToUtc(value: string): Date {
  const parsed = parseCalendarDate(value);
  if (!parsed) {
    throw new Error(`Invalid calendar date: ${value}`);
  }
  return parsed;
}

export function toDateOnlyString(
  value: Date | null | undefined,
): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function todayUtcDateOnly(now = new Date()): string {
  return toDateOnlyString(now) as string;
}

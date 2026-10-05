import { BadRequestException } from '@nestjs/common';
import { formatInTimeZone } from 'date-fns-tz';
import { ptBR } from 'date-fns/locale';

/** ISO-8601 datetime that includes Z or a numeric offset. Naive datetimes are rejected. */
export const ISO_WITH_OFFSET =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?(?:Z|[+-]\d{2}:\d{2})$/;

export function parseFutureScheduledAt(value: string, now: Date): Date {
  if (typeof value !== 'string' || !ISO_WITH_OFFSET.test(value)) {
    throw new BadRequestException(
      'scheduledAt must be an ISO-8601 datetime with a timezone offset',
    );
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime()) || date.getTime() <= now.getTime()) {
    throw new BadRequestException('scheduledAt must be in the future');
  }
  return date;
}

/** Weekday and clock in the couple timezone, for push text. */
export function formatDatePlanWhen(
  scheduledAt: Date,
  timeZone: string,
): string {
  return formatInTimeZone(scheduledAt, timeZone, 'EEEE, HH:mm', {
    locale: ptBR,
  });
}

export function formatDatePlanClock(
  scheduledAt: Date,
  timeZone: string,
): string {
  return formatInTimeZone(scheduledAt, timeZone, 'HH:mm', { locale: ptBR });
}

export function datePlanReminderCopy(
  title: string,
  scheduledAt: Date,
  timeZone: string,
): { title: string; body: string } {
  const clock = formatDatePlanClock(scheduledAt, timeZone);
  return {
    title: 'Date em 2 horas',
    body: `"${title}" é às ${clock}`,
  };
}

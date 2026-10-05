import {
  calendarYmdInTimeZone,
  diffCalendarDays,
  nextYearlyOnOrAfter,
} from '../couple/couple-calendar';

export const GIFT_REMINDER_OFFSET_DAYS = 14;

export type GiftReminderKind = 'birthday' | 'anniversary';

export interface GiftReminderOccasion {
  kind: GiftReminderKind;
  /** Birthday person. Null for the couple anniversary. */
  subjectUserId: string | null;
  displayName: string;
  occurrenceDate: string;
}

/**
 * Partner birthday or couple anniversary landing exactly 14 days out.
 * The regular D-7 / D-1 / D-0 feed reminders do not use this offset.
 */
export function giftReminderOccasions(input: {
  timezone: string;
  now: Date;
  anniversaryDate: Date | null;
  birthdays: { userId: string; name: string | null; birthDate: Date | null }[];
}): GiftReminderOccasion[] {
  const today = calendarYmdInTimeZone(input.now, input.timezone);
  const found: GiftReminderOccasion[] = [];

  const consider = (
    occurrence: string,
    occasion: Omit<GiftReminderOccasion, 'occurrenceDate'>,
  ) => {
    if (diffCalendarDays(today, occurrence) !== GIFT_REMINDER_OFFSET_DAYS) {
      return;
    }
    found.push({ ...occasion, occurrenceDate: occurrence });
  };

  if (input.anniversaryDate) {
    const { month, day } = monthDay(input.anniversaryDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'anniversary',
      subjectUserId: null,
      displayName: 'namoro',
    });
  }

  for (const birthday of input.birthdays) {
    if (!birthday.birthDate) continue;
    const { month, day } = monthDay(birthday.birthDate);
    consider(nextYearlyOnOrAfter(month, day, today), {
      kind: 'birthday',
      subjectUserId: birthday.userId,
      displayName: displayName(birthday.name),
    });
  }

  return found;
}

/**
 * Lock-screen copy for the owner only. The gift name is never an input.
 */
export function giftReminderCopy(input: {
  kind: GiftReminderKind;
  displayName: string;
  ideaCount: number;
}): { title: string; body: string } {
  const ideas =
    input.ideaCount === 1
      ? '1 ideia anotada'
      : `${input.ideaCount} ideias anotadas`;
  const subject =
    input.kind === 'anniversary'
      ? 'Aniversário de namoro'
      : `Aniversário de ${input.displayName}`;
  return {
    title: 'Ideias de presente',
    body: `${subject} em 14 dias — você tem ${ideas}`,
  };
}

function monthDay(date: Date): { month: number; day: number } {
  return { month: date.getUTCMonth() + 1, day: date.getUTCDate() };
}

function displayName(name: string | null): string {
  const trimmed = name?.trim();
  return trimmed ? trimmed : 'Parceiro';
}

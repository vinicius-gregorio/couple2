import { calendarDateToUtc } from '../common/calendar-date';
import { giftReminderCopy, giftReminderOccasions } from './gift-reminder';

describe('gift reminder', () => {
  const now = new Date('2026-10-05T12:00:00.000Z');

  it('selects a partner birthday and the anniversary only at D-14', () => {
    const found = giftReminderOccasions({
      timezone: 'America/Sao_Paulo',
      now,
      anniversaryDate: calendarDateToUtc('2020-10-19'),
      birthdays: [
        {
          userId: 'bia',
          name: 'Bia',
          birthDate: calendarDateToUtc('1992-10-19'),
        },
        {
          userId: 'ana',
          name: 'Ana',
          birthDate: calendarDateToUtc('1991-10-12'),
        },
      ],
    });

    expect(found).toEqual([
      expect.objectContaining({
        kind: 'anniversary',
        occurrenceDate: '2026-10-19',
        subjectUserId: null,
      }),
      expect.objectContaining({
        kind: 'birthday',
        occurrenceDate: '2026-10-19',
        subjectUserId: 'bia',
        displayName: 'Bia',
      }),
    ]);
  });

  it('keeps the gift name out of the lock-screen copy', () => {
    const copy = giftReminderCopy({
      kind: 'birthday',
      displayName: 'Bia',
      ideaCount: 2,
    });
    expect(copy.body).toBe(
      'Aniversário de Bia em 14 dias — você tem 2 ideias anotadas',
    );
    expect(copy.title).toBe('Ideias de presente');
    expect(copy.body).not.toContain('Pulseira');

    expect(
      giftReminderCopy({
        kind: 'anniversary',
        displayName: 'namoro',
        ideaCount: 1,
      }).body,
    ).toBe('Aniversário de namoro em 14 dias — você tem 1 ideia anotada');
  });
});

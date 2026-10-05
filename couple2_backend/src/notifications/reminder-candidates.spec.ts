import { calendarDateToUtc } from '../common/calendar-date';
import { reminderCandidates } from './reminder-candidates';

describe('reminder candidates', () => {
  const now = new Date('2026-10-05T12:00:00.000Z');

  it('selects D-7, D-1 and D0 and skips the days in between', () => {
    const found = reminderCandidates({
      coupleId: 'couple-1',
      timezone: 'America/Sao_Paulo',
      now,
      anniversaryDate: calendarDateToUtc('2020-10-05'),
      birthdays: [
        {
          userId: 'user-b',
          name: 'Bia',
          birthDate: calendarDateToUtc('1992-10-12'),
        },
        {
          userId: 'user-a',
          name: 'Ana',
          birthDate: calendarDateToUtc('1991-10-06'),
        },
      ],
      dates: [
        {
          id: 'date-1',
          title: 'Primeiro beijo',
          date: calendarDateToUtc('2019-10-07'),
          recurrence: 'YEARLY',
        },
      ],
    });

    expect(
      found.map((item) => [item.kind, item.inDays, item.entityId]),
    ).toEqual([
      ['anniversary', 0, 'couple-1'],
      ['birthday', 7, 'user-b'],
      ['birthday', 1, 'user-a'],
    ]);
    expect(found.find((item) => item.entityId === 'user-b')?.title).toBe(
      'Aniversário de Bia',
    );
    expect(
      found.find((item) => item.entityId === 'user-b')?.occurrenceDate,
    ).toBe('2026-10-12');
  });

  it('moves a Feb 29 birthday to Feb 28 in a non-leap year', () => {
    const found = reminderCandidates({
      coupleId: 'couple-1',
      timezone: 'America/Sao_Paulo',
      now: new Date('2026-02-21T12:00:00.000Z'),
      anniversaryDate: null,
      birthdays: [
        {
          userId: 'user-b',
          name: 'Bia',
          birthDate: calendarDateToUtc('1992-02-29'),
        },
      ],
      dates: [],
    });

    expect(found).toEqual([
      expect.objectContaining({
        occurrenceDate: '2026-02-28',
        inDays: 7,
        entityId: 'user-b',
      }),
    ]);
  });
});

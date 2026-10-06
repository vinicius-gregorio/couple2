import { buildUpcoming, daysTogether } from './couple-calendar';

const anniversary = new Date('2024-10-05T00:00:00.000Z');
const saoPaulo = 'America/Sao_Paulo';

describe('daysTogether', () => {
  it('counts the anniversary date as day 1 in the couple timezone', () => {
    // 05/10/2026 23:30 in America/Sao_Paulo is already 06/10 02:30 UTC.
    const lateEvening = new Date('2026-10-06T02:30:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: anniversary,
        pairedAt: new Date('2026-01-01T00:00:00.000Z'),
        timezone: saoPaulo,
        now: lateEvening,
      }),
    ).toBe(731);

    // 00:10 the next local day.
    const justAfterMidnight = new Date('2026-10-06T03:10:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: anniversary,
        pairedAt: new Date('2026-01-01T00:00:00.000Z'),
        timezone: saoPaulo,
        now: justAfterMidnight,
      }),
    ).toBe(732);
  });

  it('uses the pairedAt calendar day in the couple timezone when anniversary is unset', () => {
    // 23:30 Sao Paulo on Oct 5, which is Oct 6 02:30 UTC.
    const pairedAt = new Date('2026-10-06T02:30:00.000Z');
    const now = new Date('2026-10-06T03:10:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: null,
        pairedAt,
        timezone: saoPaulo,
        now,
      }),
    ).toBe(2);
  });
});

describe('buildUpcoming', () => {
  it('shows a Feb 29 birthday as Feb 28 in a non-leap year', () => {
    const upcoming = buildUpcoming({
      timezone: 'UTC',
      now: new Date('2026-02-01T12:00:00.000Z'),
      anniversaryDate: null,
      birthdays: [
        {
          name: 'B',
          birthDate: new Date('2000-02-29T00:00:00.000Z'),
        },
      ],
      dates: [],
    });

    expect(upcoming).toEqual([
      {
        kind: 'birthday',
        title: 'B',
        date: '2026-02-28',
        inDays: 27,
        coupleDateId: null,
      },
    ]);
  });

  it('keeps Feb 29 in a leap year', () => {
    const upcoming = buildUpcoming({
      timezone: 'UTC',
      now: new Date('2028-02-01T12:00:00.000Z'),
      anniversaryDate: null,
      birthdays: [
        {
          name: 'B',
          birthDate: new Date('2000-02-29T00:00:00.000Z'),
        },
      ],
      dates: [],
    });

    expect(upcoming[0]).toMatchObject({
      date: '2028-02-29',
      inDays: 28,
    });
  });

  it('marks only the viewer birthday as self', () => {
    const upcoming = buildUpcoming({
      timezone: 'UTC',
      now: new Date('2026-10-05T12:00:00.000Z'),
      anniversaryDate: null,
      birthdays: [
        {
          name: 'Bruno Smoke',
          birthDate: new Date('1993-11-02T00:00:00.000Z'),
          self: true,
        },
        {
          name: 'Ana Smoke',
          birthDate: new Date('1995-11-20T00:00:00.000Z'),
        },
      ],
      dates: [],
    });

    const mine = upcoming.find((entry) => entry.title === 'Bruno Smoke');
    const partner = upcoming.find((entry) => entry.title === 'Ana Smoke');
    expect(mine).toMatchObject({ kind: 'birthday', self: true });
    expect(partner?.self).toBeUndefined();
  });

  it('omits occurrences outside the next 60 days', () => {
    const upcoming = buildUpcoming({
      timezone: 'UTC',
      now: new Date('2026-03-01T12:00:00.000Z'),
      anniversaryDate: null,
      birthdays: [
        {
          name: 'B',
          birthDate: new Date('2000-02-29T00:00:00.000Z'),
        },
      ],
      dates: [
        {
          id: 'once',
          title: 'Far away',
          date: new Date('2026-06-01T00:00:00.000Z'),
          recurrence: 'NONE',
        },
      ],
    });

    expect(upcoming).toEqual([]);
  });
});

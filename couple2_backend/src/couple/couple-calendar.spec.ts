import { buildUpcoming, daysTogether } from './couple-calendar';

const anniversary = new Date('2024-10-05T00:00:00.000Z');
const saoPaulo = 'America/Sao_Paulo';

describe('daysTogether', () => {
  it('counts elapsed days, so the start evening is one less than the next midnight', () => {
    // 05/10/2026 23:30 in America/Sao_Paulo is already 06/10 02:30 UTC.
    const lateEvening = new Date('2026-10-06T02:30:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: anniversary,
        pairedAt: new Date('2026-01-01T00:00:00.000Z'),
        timezone: saoPaulo,
        now: lateEvening,
      }),
    ).toBe(730);

    // 00:10 the next local day.
    const justAfterMidnight = new Date('2026-10-06T03:10:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: anniversary,
        pairedAt: new Date('2026-01-01T00:00:00.000Z'),
        timezone: saoPaulo,
        now: justAfterMidnight,
      }),
    ).toBe(731);
  });

  it('counts 10/10 through 15/10 as 5 elapsed days', () => {
    const start = new Date('2026-10-10T00:00:00.000Z');
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: 'UTC',
        now: new Date('2026-10-15T12:00:00.000Z'),
      }),
    ).toBe(5);
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: 'UTC',
        now: new Date('2026-10-10T23:00:00.000Z'),
      }),
    ).toBe(0);
  });

  it('uses the couple timezone across midnight', () => {
    const start = new Date('2026-10-10T00:00:00.000Z');
    // 14/10 23:30 in America/Sao_Paulo.
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: saoPaulo,
        now: new Date('2026-10-15T02:30:00.000Z'),
      }),
    ).toBe(4);
    // 15/10 00:30 in America/Sao_Paulo.
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: saoPaulo,
        now: new Date('2026-10-15T03:30:00.000Z'),
      }),
    ).toBe(5);
    // The local start day is still 0 just before the next midnight.
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: saoPaulo,
        now: new Date('2026-10-11T02:30:00.000Z'),
      }),
    ).toBe(0);
    // 11/10 00:00 in America/Sao_Paulo.
    expect(
      daysTogether({
        anniversaryDate: start,
        pairedAt: start,
        timezone: saoPaulo,
        now: new Date('2026-10-11T03:00:00.000Z'),
      }),
    ).toBe(1);
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
    ).toBe(1);
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

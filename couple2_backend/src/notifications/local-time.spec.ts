import { isLocalHour, isQuietNow, localMinutesOfDay } from './local-time';

const SAO_PAULO = 'America/Sao_Paulo';

describe('quiet hours', () => {
  // 23:30 in America/Sao_Paulo (UTC-3, no DST in October).
  const at2330 = new Date('2026-10-06T02:30:00.000Z');
  const at0900 = new Date('2026-10-05T12:00:00.000Z');
  const at0700 = new Date('2026-10-05T10:00:00.000Z');
  const at2300 = new Date('2026-10-06T02:00:00.000Z');
  const at0200 = new Date('2026-10-05T05:00:00.000Z');

  it('treats 23:00–07:00 as a window that wraps midnight', () => {
    expect(localMinutesOfDay(at2330, SAO_PAULO)).toBe(23 * 60 + 30);
    expect(isQuietNow(at2330, SAO_PAULO, 1380, 7 * 60)).toBe(true);
    expect(isQuietNow(at2300, SAO_PAULO, 1380, 7 * 60)).toBe(true);
    expect(isQuietNow(at0200, SAO_PAULO, 1380, 7 * 60)).toBe(true);
    expect(isQuietNow(at0700, SAO_PAULO, 1380, 7 * 60)).toBe(false);
    expect(isQuietNow(at0900, SAO_PAULO, 1380, 7 * 60)).toBe(false);
  });

  it('does nothing when a bound is missing or the window has no length', () => {
    expect(isQuietNow(at2330, SAO_PAULO, null, 420)).toBe(false);
    expect(isQuietNow(at2330, SAO_PAULO, 1380, null)).toBe(false);
    expect(isQuietNow(at2330, SAO_PAULO, 1380, 1380)).toBe(false);
  });

  it('keeps a same-day window inside the start and before the end', () => {
    const at1300 = new Date('2026-10-05T16:00:00.000Z');
    expect(isQuietNow(at1300, SAO_PAULO, 12 * 60, 14 * 60)).toBe(true);
    expect(isQuietNow(at0900, SAO_PAULO, 12 * 60, 14 * 60)).toBe(false);
  });
});

describe('local hour', () => {
  it('matches 09:00 in the couple timezone', () => {
    const at0900 = new Date('2026-10-05T12:00:00.000Z');
    const at0800 = new Date('2026-10-05T11:00:00.000Z');
    expect(isLocalHour(at0900, SAO_PAULO, 9)).toBe(true);
    expect(isLocalHour(at0800, SAO_PAULO, 9)).toBe(false);
  });
});

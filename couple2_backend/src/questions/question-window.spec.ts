import { isAnswerableDate, isOutsideAnswerWindow } from './question-window';

describe('answer window', () => {
  const today = '2026-10-05';

  it('rejects 8 days ago and accepts 7 and 6', () => {
    expect(isOutsideAnswerWindow('2026-09-27', today)).toBe(true);
    expect(isOutsideAnswerWindow('2026-09-28', today)).toBe(false);
    expect(isOutsideAnswerWindow('2026-09-29', today)).toBe(false);
    expect(isOutsideAnswerWindow(today, today)).toBe(false);
  });

  it('marks locked or old rows as not answerable', () => {
    expect(isAnswerableDate('2026-09-29', today, false)).toBe(true);
    expect(isAnswerableDate('2026-09-27', today, false)).toBe(false);
    expect(isAnswerableDate(today, today, true)).toBe(false);
  });
});

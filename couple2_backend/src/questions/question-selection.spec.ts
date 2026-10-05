import { toDateOnlyString } from '../common/calendar-date';
import { calendarYmdInTimeZone } from '../couple/couple-calendar';
import {
  chooseQuestion,
  isRecentDeep,
  type QuestionCandidate,
  type UsedQuestion,
} from './question-selection';

function ymdFromDay(dayIndex: number): string {
  return toDateOnlyString(new Date(Date.UTC(2026, 0, 1 + dayIndex))) as string;
}

function bank(
  count: number,
  category: QuestionCandidate['category'] = 'FUN',
): QuestionCandidate[] {
  return Array.from({ length: count }, (_, index) => ({
    id: `q-${category}-${index}`,
    slug: `${category.toLowerCase()}-${String(index).padStart(3, '0')}`,
    category,
  }));
}

describe('chooseQuestion', () => {
  const first = (candidates: QuestionCandidate[]) => candidates[0];

  it('does not repeat a question across 120 days, then reuses the least recent', () => {
    const active = bank(120);
    const used: UsedQuestion[] = [];
    const assigned: string[] = [];

    for (let day = 0; day < 120; day += 1) {
      const choice = chooseQuestion({
        active,
        used,
        today: ymdFromDay(day),
        pick: first,
      });
      expect(choice).not.toBeNull();
      expect(choice?.fallback).toBe(false);
      assigned.push(choice!.question.id);
      used.push({
        questionId: choice!.question.id,
        lastUsedOn: ymdFromDay(day),
        category: choice!.question.category,
      });
    }

    expect(new Set(assigned).size).toBe(120);

    const exhausted = chooseQuestion({
      active,
      used,
      today: ymdFromDay(120),
      pick: first,
    });
    expect(exhausted?.fallback).toBe(true);
    expect(exhausted?.question.id).toBe(assigned[0]);
    expect(exhausted?.lastUsedOn).toBe(ymdFromDay(0));
  });

  it('keeps DEEP to at most one assignment per 7 days while other questions remain', () => {
    const active = [...bank(1, 'DEEP'), ...bank(3, 'FUN')];
    const today = '2026-10-05';
    const choice = chooseQuestion({
      active,
      used: [
        {
          questionId: active[0].id,
          lastUsedOn: '2026-10-02',
          category: 'DEEP',
        },
      ],
      today,
      pick: first,
    });
    expect(isRecentDeep('2026-10-02', today)).toBe(true);
    expect(isRecentDeep('2026-09-28', today)).toBe(false);
    expect(choice?.question.category).not.toBe('DEEP');
    expect(choice?.fallback).toBe(false);
  });

  it('reuses the least recent question when the only fresh rows are DEEP inside the gap', () => {
    const deep = bank(2, 'DEEP');
    const fun = bank(1, 'FUN')[0];
    const choice = chooseQuestion({
      active: [...deep, fun],
      used: [
        { questionId: deep[0].id, lastUsedOn: '2026-10-04', category: 'DEEP' },
        { questionId: fun.id, lastUsedOn: '2026-10-01', category: 'FUN' },
      ],
      today: '2026-10-05',
      pick: first,
    });
    expect(choice?.fallback).toBe(true);
    expect(choice?.question.id).toBe(fun.id);
  });
});

describe('couple today boundary', () => {
  it('changes the calendar day between 23:59 and 00:01 in the couple timezone', () => {
    const zone = 'America/Sao_Paulo';
    const beforeMidnight = new Date('2026-10-06T02:59:00.000Z');
    const afterMidnight = new Date('2026-10-06T03:01:00.000Z');
    expect(calendarYmdInTimeZone(beforeMidnight, zone)).toBe('2026-10-05');
    expect(calendarYmdInTimeZone(afterMidnight, zone)).toBe('2026-10-06');
  });
});

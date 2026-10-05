import { diffCalendarDays } from '../couple/couple-calendar';

export const QUESTION_CATEGORIES = [
  'FUN',
  'DEEP',
  'MEMORIES',
  'FUTURE',
  'DAILY_LIFE',
] as const;

export type QuestionCategoryName = (typeof QUESTION_CATEGORIES)[number];

/** A new DEEP question is allowed only when the last one is at least this many days old. */
export const DEEP_MIN_GAP_DAYS = 7;

export interface QuestionCandidate {
  id: string;
  slug: string;
  category: QuestionCategoryName;
}

export interface UsedQuestion {
  questionId: string;
  /** Calendar day of the most recent assignment, `YYYY-MM-DD`. */
  lastUsedOn: string;
  category: QuestionCategoryName;
}

export interface ChooseResult {
  question: QuestionCandidate;
  fallback: boolean;
  /** True only when reuse had to pick DEEP inside the weekly gap because nothing else was active. */
  relaxedDeepCap: boolean;
  lastUsedOn: string | null;
}

export function isRecentDeep(
  lastDeepYmd: string | null,
  todayYmd: string,
): boolean {
  if (!lastDeepYmd) return false;
  const age = diffCalendarDays(lastDeepYmd, todayYmd);
  return age >= 0 && age < DEEP_MIN_GAP_DAYS;
}

export function pickRandom(candidates: QuestionCandidate[]): QuestionCandidate {
  const index = Math.floor(Math.random() * candidates.length);
  return candidates[index];
}

/**
 * Prefer an active question this couple has never received.
 * DEEP is left out of that draw when one was assigned in the last 7 days.
 * When nothing fresh is eligible, reuse the least-recently assigned active
 * question and mark `fallback` so the caller can log a warning.
 */
export function chooseQuestion(input: {
  active: QuestionCandidate[];
  used: UsedQuestion[];
  today: string;
  pick?: (candidates: QuestionCandidate[]) => QuestionCandidate;
}): ChooseResult | null {
  if (input.active.length === 0) return null;

  const pick = input.pick ?? pickRandom;
  const activeById = new Map(
    input.active.map((question) => [question.id, question]),
  );
  const usedIds = new Set<string>();
  let lastDeep: string | null = null;
  const reusable: UsedQuestion[] = [];

  for (const row of input.used) {
    if (!activeById.has(row.questionId)) continue;
    usedIds.add(row.questionId);
    reusable.push(row);
    if (row.category === 'DEEP' && (!lastDeep || row.lastUsedOn > lastDeep)) {
      lastDeep = row.lastUsedOn;
    }
  }

  const unused = input.active.filter((question) => !usedIds.has(question.id));
  const recentDeep = isRecentDeep(lastDeep, input.today);
  const fresh = recentDeep
    ? unused.filter((question) => question.category !== 'DEEP')
    : unused;

  if (fresh.length > 0) {
    return {
      question: pick(sortBySlug(fresh)),
      fallback: false,
      relaxedDeepCap: false,
      lastUsedOn: null,
    };
  }

  if (unused.length > 0 && reusable.every((row) => row.category === 'DEEP')) {
    return {
      question: pick(sortBySlug(unused)),
      fallback: false,
      relaxedDeepCap: true,
      lastUsedOn: null,
    };
  }

  reusable.sort((a, b) => {
    if (a.lastUsedOn !== b.lastUsedOn) {
      return a.lastUsedOn < b.lastUsedOn ? -1 : 1;
    }
    return a.questionId < b.questionId
      ? -1
      : a.questionId > b.questionId
        ? 1
        : 0;
  });

  const bankExhausted = unused.length === 0;
  const preferred = bankExhausted
    ? reusable
    : reusable.filter((row) => row.category !== 'DEEP');
  const chosenRow = preferred[0] ?? reusable[0];
  if (!chosenRow) return null;

  const question = activeById.get(chosenRow.questionId);
  if (!question) return null;

  return {
    question,
    fallback: true,
    relaxedDeepCap: recentDeep && question.category === 'DEEP',
    lastUsedOn: chosenRow.lastUsedOn,
  };
}

function sortBySlug(questions: QuestionCandidate[]): QuestionCandidate[] {
  return questions.slice().sort((a, b) => a.slug.localeCompare(b.slug));
}

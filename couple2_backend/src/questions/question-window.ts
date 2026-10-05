import { diffCalendarDays } from '../couple/couple-calendar';

/** `date < today - 7` is rejected. The day exactly 7 days ago is still answerable. */
export const ANSWER_WINDOW_DAYS = 7;

export function daysSinceQuestion(
  questionYmd: string,
  todayYmd: string,
): number {
  return diffCalendarDays(questionYmd, todayYmd);
}

export function isOutsideAnswerWindow(
  questionYmd: string,
  todayYmd: string,
): boolean {
  return daysSinceQuestion(questionYmd, todayYmd) > ANSWER_WINDOW_DAYS;
}

/** Editable while locked and the calendar day is still inside the 7-day window. */
export function isAnswerableDate(
  questionYmd: string,
  todayYmd: string,
  unlocked: boolean,
): boolean {
  if (unlocked) return false;
  const age = daysSinceQuestion(questionYmd, todayYmd);
  return age >= 0 && age <= ANSWER_WINDOW_DAYS;
}

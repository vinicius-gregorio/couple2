import { isAnswerableDate } from './question-window';

export interface AnswerView {
  text: string;
  createdAt: string;
  updatedAt: string;
}

export interface CoupleQuestionView {
  id: string;
  date: string;
  question: { text: string; category: string };
  myAnswer: AnswerView | null;
  partnerAnswered: boolean;
  unlockedAt: string | null;
  /** Derived: locked and the calendar day is still inside the 7-day window. */
  answerable: boolean;
  /** Present only when unlockedAt is set. Omitted entirely while locked. */
  partnerAnswer?: AnswerView;
}

export interface AnswerSnapshot {
  text: string;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Partner text is attached only when the row is unlocked. Callers must also
 * avoid selecting that text while locked; this builder is the last gate so a
 * serializer cannot leak it.
 */
export function buildCoupleQuestionView(input: {
  id: string;
  date: string;
  questionText: string;
  category: string;
  unlockedAt: Date | null;
  today: string;
  myAnswer: AnswerSnapshot | null;
  partnerAnswered: boolean;
  partnerAnswer: AnswerSnapshot | null;
}): CoupleQuestionView {
  const unlockedAt = input.unlockedAt;
  const unlocked = unlockedAt != null;
  const view: CoupleQuestionView = {
    id: input.id,
    date: input.date,
    question: { text: input.questionText, category: input.category },
    myAnswer: input.myAnswer ? toAnswerView(input.myAnswer) : null,
    partnerAnswered: input.partnerAnswered,
    unlockedAt: unlocked ? unlockedAt.toISOString() : null,
    answerable: isAnswerableDate(input.date, input.today, unlocked),
  };
  if (unlocked && input.partnerAnswer) {
    view.partnerAnswer = toAnswerView(input.partnerAnswer);
  }
  return view;
}

function toAnswerView(answer: AnswerSnapshot): AnswerView {
  return {
    text: answer.text,
    createdAt: answer.createdAt.toISOString(),
    updatedAt: answer.updatedAt.toISOString(),
  };
}

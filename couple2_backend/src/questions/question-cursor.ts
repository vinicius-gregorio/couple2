import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { calendarDateToUtc } from '../common/calendar-date';

export interface QuestionCursor {
  date: string;
  id: string;
}

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

export function encodeQuestionCursor(item: QuestionCursor): string {
  return Buffer.from(`${item.date}|${item.id}`, 'utf8').toString('base64url');
}

export function decodeQuestionCursor(cursor: string): QuestionCursor {
  let raw: string;
  try {
    raw = Buffer.from(cursor, 'base64url').toString('utf8');
  } catch {
    throw new BadRequestException('Invalid cursor');
  }
  const separator = raw.indexOf('|');
  if (separator <= 0) throw new BadRequestException('Invalid cursor');
  const date = raw.slice(0, separator);
  const id = raw.slice(separator + 1);
  if (!DATE_ONLY.test(date) || id.length === 0) {
    throw new BadRequestException('Invalid cursor');
  }
  return { date, id };
}

/** Keyset page on (date desc, id desc), scoped to one couple. */
export function buildQuestionHistoryWhere(
  coupleId: string,
  cursor: QuestionCursor | null,
): Prisma.CoupleQuestionWhereInput {
  if (!cursor) return { coupleId };
  const date = calendarDateToUtc(cursor.date);
  return {
    coupleId,
    OR: [
      { date: { lt: date } },
      { AND: [{ date }, { id: { lt: cursor.id } }] },
    ],
  };
}

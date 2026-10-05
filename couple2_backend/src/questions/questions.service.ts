import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ActivityType, Prisma, QuestionCategory } from '@prisma/client';
import { calendarDateToUtc, toDateOnlyString } from '../common/calendar-date';
import { calendarYmdInTimeZone } from '../couple/couple-calendar';
import { ActivityService } from '../notifications/activity.service';
import type { RecordActivityInput } from '../notifications/activity.service';
import { truncateContent } from '../notifications/json-record';
import { isUniqueViolation } from '../notifications/prisma-errors';
import { PrismaService } from '../prisma';
import {
  buildQuestionHistoryWhere,
  decodeQuestionCursor,
  encodeQuestionCursor,
} from './question-cursor';
import {
  chooseQuestion,
  type QuestionCategoryName,
} from './question-selection';
import {
  buildCoupleQuestionView,
  type AnswerSnapshot,
  type CoupleQuestionView,
} from './question-view';
import { isOutsideAnswerWindow } from './question-window';

const ANSWER_SELECT = {
  text: true,
  createdAt: true,
  updatedAt: true,
} as const;

@Injectable()
export class QuestionsService {
  private readonly logger = new Logger(QuestionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  async getToday(
    userId: string,
    couple: { id: string; timezone: string },
    now = new Date(),
  ): Promise<CoupleQuestionView> {
    const today = calendarYmdInTimeZone(now, couple.timezone);
    const id = await this.ensureForDate(couple.id, today);
    return this.present(id, couple.id, userId, today);
  }

  async history(
    userId: string,
    couple: { id: string; timezone: string },
    query: { cursor?: string; limit?: number },
    now = new Date(),
  ): Promise<{ items: CoupleQuestionView[]; nextCursor: string | null }> {
    const today = calendarYmdInTimeZone(now, couple.timezone);
    const limit = query.limit ?? 20;
    const cursor = query.cursor ? decodeQuestionCursor(query.cursor) : null;
    const rows = await this.prisma.coupleQuestion.findMany({
      where: buildQuestionHistoryWhere(couple.id, cursor),
      orderBy: [{ date: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        date: true,
        unlockedAt: true,
        question: { select: { text: true, category: true } },
        answers: { select: { userId: true } },
      },
    });
    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const ids = page.map((row) => row.id);
    const myAnswers =
      ids.length === 0
        ? []
        : await this.prisma.questionAnswer.findMany({
            where: { userId, coupleQuestionId: { in: ids } },
            select: { coupleQuestionId: true, ...ANSWER_SELECT },
          });
    const unlockedIds = page
      .filter((row) => row.unlockedAt != null)
      .map((row) => row.id);
    // Partner text is selected only for rows that are already unlocked.
    const partnerAnswers =
      unlockedIds.length === 0
        ? []
        : await this.prisma.questionAnswer.findMany({
            where: {
              coupleQuestionId: { in: unlockedIds },
              userId: { not: userId },
            },
            select: { coupleQuestionId: true, ...ANSWER_SELECT },
          });

    const mineByQuestion = new Map(
      myAnswers.map((answer) => [answer.coupleQuestionId, answer]),
    );
    const partnerByQuestion = new Map(
      partnerAnswers.map((answer) => [answer.coupleQuestionId, answer]),
    );

    const items = page.map((row) => {
      const date = toDateOnlyString(row.date) ?? today;
      const mine = mineByQuestion.get(row.id) ?? null;
      const partner = partnerByQuestion.get(row.id) ?? null;
      return buildCoupleQuestionView({
        id: row.id,
        date,
        questionText: row.question.text,
        category: row.question.category,
        unlockedAt: row.unlockedAt,
        today,
        myAnswer: mine,
        partnerAnswered: row.answers.some((answer) => answer.userId !== userId),
        partnerAnswer: row.unlockedAt != null ? partner : null,
      });
    });

    const last = page[page.length - 1];
    const lastDate = last ? toDateOnlyString(last.date) : null;
    return {
      items,
      nextCursor:
        hasMore && last && lastDate
          ? encodeQuestionCursor({ date: lastDate, id: last.id })
          : null,
    };
  }

  async answer(
    userId: string,
    couple: { id: string; timezone: string },
    coupleQuestionId: string,
    rawText: string,
    now = new Date(),
  ): Promise<CoupleQuestionView> {
    const text = rawText.trim();
    if (text.length < 1 || text.length > 1000) {
      throw new BadRequestException(
        'Answer must be between 1 and 1000 characters',
      );
    }

    const today = calendarYmdInTimeZone(now, couple.timezone);
    const outcome = await this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT "id" FROM "couple_questions" WHERE "id" = ${coupleQuestionId} AND "coupleId" = ${couple.id} FOR UPDATE`,
      );
      if (locked.length === 0) {
        throw new NotFoundException('Question not found');
      }

      const row = await tx.coupleQuestion.findFirst({
        where: { id: coupleQuestionId, coupleId: couple.id },
        select: {
          id: true,
          date: true,
          unlockedAt: true,
          question: { select: { text: true } },
          answers: { select: { id: true, userId: true } },
        },
      });
      if (!row) throw new NotFoundException('Question not found');

      const date = toDateOnlyString(row.date);
      if (!date || isOutsideAnswerWindow(date, today)) {
        throw new UnprocessableEntityException(
          'Question is outside the 7-day window',
        );
      }
      if (row.unlockedAt) {
        throw new ConflictException('Question is already unlocked');
      }

      const mine = row.answers.find((answer) => answer.userId === userId);
      const partnerAnswered = row.answers.some(
        (answer) => answer.userId !== userId,
      );

      if (mine) {
        await tx.questionAnswer.update({
          where: { id: mine.id },
          data: { text },
        });
        return {
          created: false,
          unlocked: false,
          questionText: row.question.text,
        };
      }

      await tx.questionAnswer.create({
        data: { coupleQuestionId, userId, text },
      });

      if (partnerAnswered) {
        await tx.coupleQuestion.update({
          where: { id: coupleQuestionId },
          data: { unlockedAt: now },
        });
        return {
          created: true,
          unlocked: true,
          questionText: row.question.text,
        };
      }

      return {
        created: true,
        unlocked: false,
        questionText: row.question.text,
      };
    });

    if (outcome.created) {
      await this.safeRecord({
        coupleId: couple.id,
        actorId: userId,
        type: outcome.unlocked
          ? ActivityType.QUESTION_UNLOCKED
          : ActivityType.QUESTION_ANSWERED,
        entity: { type: 'CoupleQuestion', id: coupleQuestionId },
        payload: { questionExcerpt: truncateContent(outcome.questionText) },
        push: { route: '/question' },
      });
    }

    return this.present(coupleQuestionId, couple.id, userId, today);
  }

  /**
   * Same assignment used by GET /questions/today and the 10:00 job.
   * A unique clash on (coupleId, date) means the partner won the race:
   * re-read that row instead of inserting a second question.
   */
  async ensureForDate(coupleId: string, ymd: string): Promise<string> {
    const date = calendarDateToUtc(ymd);
    const existing = await this.prisma.coupleQuestion.findFirst({
      where: { coupleId, date },
      select: { id: true },
    });
    if (existing) return existing.id;

    const choice = await this.loadChoice(coupleId, ymd);
    if (!choice) {
      throw new ServiceUnavailableException('No active questions');
    }
    if (choice.fallback || choice.relaxedDeepCap) {
      const reason = choice.relaxedDeepCap
        ? 'deep weekly cap left no other question'
        : 'active question bank exhausted';
      const action = choice.fallback ? 'Reusing' : 'Assigning';
      this.logger.warn(
        `${action} question ${choice.question.slug} for couple ${coupleId} on ${ymd} (${reason}, last used ${choice.lastUsedOn ?? 'unknown'})`,
      );
    }

    try {
      const created = await this.prisma.coupleQuestion.create({
        data: { coupleId, questionId: choice.question.id, date },
        select: { id: true },
      });
      return created.id;
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const winner = await this.prisma.coupleQuestion.findFirst({
        where: { coupleId, date },
        select: { id: true },
      });
      if (winner) return winner.id;
      throw error;
    }
  }

  /**
   * Creates today's question if needed, then sends dailyQuestion once.
   * Claiming dailyNotifiedAt first makes a second run in the same morning a no-op.
   */
  async deliverDailyQuestion(
    couple: { id: string; timezone: string },
    now = new Date(),
  ): Promise<{ coupleQuestionId: string; pushed: boolean }> {
    const ymd = calendarYmdInTimeZone(now, couple.timezone);
    const coupleQuestionId = await this.ensureForDate(couple.id, ymd);
    const claimed = await this.prisma.coupleQuestion.updateMany({
      where: { id: coupleQuestionId, dailyNotifiedAt: null },
      data: { dailyNotifiedAt: now },
    });
    if (claimed.count === 0) {
      return { coupleQuestionId, pushed: false };
    }

    try {
      await this.activity.pushDailyQuestion({
        coupleId: couple.id,
        coupleQuestionId,
      });
    } catch (error) {
      await this.prisma.coupleQuestion.update({
        where: { id: coupleQuestionId },
        data: { dailyNotifiedAt: null },
      });
      throw error;
    }

    return { coupleQuestionId, pushed: true };
  }

  private async present(
    id: string,
    coupleId: string,
    userId: string,
    today: string,
  ): Promise<CoupleQuestionView> {
    const row = await this.prisma.coupleQuestion.findFirst({
      where: { id, coupleId },
      select: {
        id: true,
        date: true,
        unlockedAt: true,
        question: { select: { text: true, category: true } },
        answers: {
          where: { userId },
          select: ANSWER_SELECT,
        },
      },
    });
    if (!row) throw new NotFoundException('Question not found');

    const partnerCount = await this.prisma.questionAnswer.count({
      where: { coupleQuestionId: id, userId: { not: userId } },
    });

    let partnerAnswer: AnswerSnapshot | null = null;
    if (row.unlockedAt != null) {
      partnerAnswer = await this.prisma.questionAnswer.findFirst({
        where: { coupleQuestionId: id, userId: { not: userId } },
        select: ANSWER_SELECT,
      });
    }

    const date = toDateOnlyString(row.date) ?? today;
    return buildCoupleQuestionView({
      id: row.id,
      date,
      questionText: row.question.text,
      category: row.question.category,
      unlockedAt: row.unlockedAt,
      today,
      myAnswer: row.answers[0] ?? null,
      partnerAnswered: partnerCount > 0,
      partnerAnswer,
    });
  }

  private async loadChoice(coupleId: string, today: string) {
    const active = await this.prisma.question.findMany({
      where: { active: true, locale: 'pt-BR' },
      select: { id: true, slug: true, category: true },
    });
    const rows = await this.prisma.coupleQuestion.findMany({
      where: { coupleId },
      select: {
        questionId: true,
        date: true,
        question: { select: { category: true, active: true } },
      },
    });

    const lastUsed = new Map<
      string,
      { questionId: string; lastUsedOn: string; category: QuestionCategoryName }
    >();
    for (const row of rows) {
      if (!row.question.active) continue;
      const ymd = toDateOnlyString(row.date);
      if (!ymd) continue;
      const category = asCategory(row.question.category);
      const prev = lastUsed.get(row.questionId);
      if (!prev || ymd > prev.lastUsedOn) {
        lastUsed.set(row.questionId, {
          questionId: row.questionId,
          lastUsedOn: ymd,
          category,
        });
      }
    }

    return chooseQuestion({
      active: active.map((question) => ({
        id: question.id,
        slug: question.slug,
        category: asCategory(question.category),
      })),
      used: [...lastUsed.values()],
      today,
    });
  }

  private async safeRecord(input: RecordActivityInput): Promise<void> {
    try {
      await this.activity.record(input);
    } catch (error) {
      this.logger.error(
        'Activity record failed after the answer committed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }
}

function asCategory(value: QuestionCategory): QuestionCategoryName {
  switch (value) {
    case QuestionCategory.FUN:
    case QuestionCategory.DEEP:
    case QuestionCategory.MEMORIES:
    case QuestionCategory.FUTURE:
    case QuestionCategory.DAILY_LIFE:
      return value;
    default: {
      const exhaustive: never = value;
      return exhaustive;
    }
  }
}

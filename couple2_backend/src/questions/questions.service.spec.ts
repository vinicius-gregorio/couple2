/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-argument */
import {
  ConflictException,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ActivityType, QuestionCategory } from '@prisma/client';
import { calendarDateToUtc, toDateOnlyString } from '../common/calendar-date';
import type { RecordActivityInput } from '../notifications/activity.service';
import { ActivityService } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import { QuestionsService } from './questions.service';

interface QuestionRow {
  id: string;
  slug: string;
  text: string;
  locale: string;
  category: QuestionCategory;
  active: boolean;
}

interface CoupleQuestionRow {
  id: string;
  coupleId: string;
  questionId: string;
  date: Date;
  unlockedAt: Date | null;
  dailyNotifiedAt: Date | null;
  createdAt: Date;
}

interface AnswerRow {
  id: string;
  coupleQuestionId: string;
  userId: string;
  text: string;
  createdAt: Date;
  updatedAt: Date;
}

interface ReadCall {
  model: string;
  op: string;
  args: { where?: Record<string, unknown>; select?: Record<string, unknown> };
}

class MemoryDb {
  questions: QuestionRow[] = [];
  coupleQuestions: CoupleQuestionRow[] = [];
  answers: AnswerRow[] = [];
  reads: ReadCall[] = [];
  private seq = 1;
  private mutex: Promise<void> = Promise.resolve();

  next(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${this.seq}`;
  }

  private note(model: string, op: string, args: ReadCall['args']) {
    this.reads.push({ model, op, args });
  }

  private ymd(value: Date): string {
    return toDateOnlyString(value) as string;
  }

  private pick(row: Record<string, unknown>, select?: Record<string, unknown>) {
    if (!select) return row;
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(select)) {
      if (select[key]) out[key] = row[key];
    }
    return out;
  }

  private matchAnswer(row: AnswerRow, where: Record<string, unknown> = {}) {
    const userId = where.userId as { not?: string } | string | undefined;
    if (typeof userId === 'string' && row.userId !== userId) return false;
    if (userId && typeof userId === 'object' && userId.not === row.userId) {
      return false;
    }
    const coupleQuestionId = where.coupleQuestionId as
      | { in?: string[] }
      | string
      | undefined;
    if (
      typeof coupleQuestionId === 'string' &&
      row.coupleQuestionId !== coupleQuestionId
    ) {
      return false;
    }
    if (
      coupleQuestionId &&
      typeof coupleQuestionId === 'object' &&
      coupleQuestionId.in &&
      !coupleQuestionId.in.includes(row.coupleQuestionId)
    ) {
      return false;
    }
    return true;
  }

  private hydrate(row: CoupleQuestionRow, select?: Record<string, any>) {
    const question = this.questions.find((item) => item.id === row.questionId);
    const answers = this.answers.filter(
      (item) => item.coupleQuestionId === row.id,
    );
    if (!select) return { ...row, question, answers };
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(select)) {
      if (key === 'question') {
        out.question = this.pick(
          question as unknown as Record<string, unknown>,
          select.question.select,
        );
      } else if (key === 'answers') {
        let list = answers;
        const userId = select.answers.where?.userId;
        if (typeof userId === 'string') {
          list = list.filter((item) => item.userId === userId);
        } else if (userId?.not) {
          list = list.filter((item) => item.userId !== userId.not);
        }
        out.answers = list.map((item) =>
          this.pick(
            item as unknown as Record<string, unknown>,
            select.answers.select,
          ),
        );
      } else if (select[key]) {
        out[key] = (row as unknown as Record<string, unknown>)[key];
      }
    }
    return out;
  }

  private matchCouple(
    row: CoupleQuestionRow,
    where: Record<string, any>,
  ): boolean {
    if (where.id && row.id !== where.id) return false;
    if (where.coupleId && row.coupleId !== where.coupleId) return false;
    if (where.date && !(where.date instanceof Date) && !where.date.lt) {
      return false;
    }
    if (
      where.date instanceof Date &&
      this.ymd(row.date) !== this.ymd(where.date)
    ) {
      return false;
    }
    if (where.OR) {
      return where.OR.some((branch: Record<string, any>) => {
        if (branch.date?.lt)
          return row.date.getTime() < branch.date.lt.getTime();
        if (branch.AND) {
          const date = branch.AND[0].date as Date;
          const idLt = branch.AND[1].id.lt as string;
          return this.ymd(row.date) === this.ymd(date) && row.id < idLt;
        }
        return false;
      });
    }
    return true;
  }

  coupleQuestion = {
    findFirst: async (args: {
      where: Record<string, any>;
      select?: Record<string, any>;
    }) => {
      this.note('coupleQuestion', 'findFirst', args);
      await Promise.resolve();
      const row = this.coupleQuestions.find((item) =>
        this.matchCouple(item, args.where),
      );
      return row ? this.hydrate(row, args.select) : null;
    },
    findMany: async (args: {
      where: Record<string, any>;
      select?: Record<string, any>;
      orderBy?: unknown;
      take?: number;
    }) => {
      this.note('coupleQuestion', 'findMany', args);
      await Promise.resolve();
      const rows = this.coupleQuestions
        .filter((item) => this.matchCouple(item, args.where))
        .sort((a, b) => {
          const byDate = b.date.getTime() - a.date.getTime();
          if (byDate !== 0) return byDate;
          return a.id < b.id ? 1 : -1;
        });
      const page = args.take ? rows.slice(0, args.take) : rows;
      return page.map((row) => this.hydrate(row, args.select));
    },
    create: async (args: {
      data: Record<string, any>;
      select?: Record<string, any>;
    }) => {
      this.note('coupleQuestion', 'create', args);
      await Promise.resolve();
      const date = args.data.date as Date;
      const key = `${args.data.coupleId}|${this.ymd(date)}`;
      if (
        this.coupleQuestions.some(
          (row) => `${row.coupleId}|${this.ymd(row.date)}` === key,
        )
      ) {
        const error = new Error('Unique constraint failed');
        (error as { code?: string }).code = 'P2002';
        throw error;
      }
      const row: CoupleQuestionRow = {
        id: this.next('cq'),
        coupleId: args.data.coupleId,
        questionId: args.data.questionId,
        date,
        unlockedAt: null,
        dailyNotifiedAt: null,
        createdAt: new Date(),
      };
      this.coupleQuestions.push(row);
      return this.hydrate(row, args.select);
    },
    update: async (args: {
      where: { id: string };
      data: Record<string, unknown>;
    }) => {
      await Promise.resolve();
      const row = this.coupleQuestions.find(
        (item) => item.id === args.where.id,
      );
      if (!row) throw new Error('missing couple question');
      if ('unlockedAt' in args.data)
        row.unlockedAt = args.data.unlockedAt as Date | null;
      if ('dailyNotifiedAt' in args.data) {
        row.dailyNotifiedAt = args.data.dailyNotifiedAt as Date | null;
      }
      return row;
    },
    updateMany: async (args: {
      where: { id: string; dailyNotifiedAt: null };
      data: { dailyNotifiedAt: Date };
    }) => {
      await Promise.resolve();
      const row = this.coupleQuestions.find(
        (item) => item.id === args.where.id,
      );
      if (!row || row.dailyNotifiedAt != null) return { count: 0 };
      row.dailyNotifiedAt = args.data.dailyNotifiedAt;
      return { count: 1 };
    },
  };

  question = {
    findMany: async (args: {
      where?: Record<string, unknown>;
      select?: Record<string, unknown>;
    }) => {
      this.note('question', 'findMany', args);
      await Promise.resolve();
      return this.questions
        .filter((row) => {
          if (args.where?.active === true && !row.active) return false;
          if (args.where?.locale && row.locale !== args.where.locale)
            return false;
          return true;
        })
        .map((row) =>
          this.pick(row as unknown as Record<string, unknown>, args.select),
        );
    },
  };

  questionAnswer = {
    findMany: async (args: {
      where: Record<string, unknown>;
      select?: Record<string, unknown>;
    }) => {
      this.note('questionAnswer', 'findMany', args);
      await Promise.resolve();
      return this.answers
        .filter((row) => this.matchAnswer(row, args.where))
        .map((row) =>
          this.pick(row as unknown as Record<string, unknown>, args.select),
        );
    },
    findFirst: async (args: {
      where: Record<string, unknown>;
      select?: Record<string, unknown>;
    }) => {
      this.note('questionAnswer', 'findFirst', args);
      await Promise.resolve();
      const row = this.answers.find((item) =>
        this.matchAnswer(item, args.where),
      );
      return row
        ? this.pick(row as unknown as Record<string, unknown>, args.select)
        : null;
    },
    count: async (args: { where: Record<string, unknown> }) => {
      this.note('questionAnswer', 'count', args);
      await Promise.resolve();
      return this.answers.filter((row) => this.matchAnswer(row, args.where))
        .length;
    },
    create: async (args: { data: Record<string, any> }) => {
      await Promise.resolve();
      if (
        this.answers.some(
          (row) =>
            row.coupleQuestionId === args.data.coupleQuestionId &&
            row.userId === args.data.userId,
        )
      ) {
        const error = new Error('Unique constraint failed');
        (error as { code?: string }).code = 'P2002';
        throw error;
      }
      const now = new Date();
      const row: AnswerRow = {
        id: this.next('a'),
        coupleQuestionId: args.data.coupleQuestionId,
        userId: args.data.userId,
        text: args.data.text,
        createdAt: now,
        updatedAt: now,
      };
      this.answers.push(row);
      return row;
    },
    update: async (args: { where: { id: string }; data: { text: string } }) => {
      await Promise.resolve();
      const row = this.answers.find((item) => item.id === args.where.id);
      if (!row) throw new Error('missing answer');
      row.text = args.data.text;
      row.updatedAt = new Date(row.updatedAt.getTime() + 60_000);
      return row;
    },
  };

  $queryRaw = async (query: { values?: unknown[] }) => {
    await Promise.resolve();
    const id = asQueryId(query.values?.[0]);
    const coupleId = asQueryId(query.values?.[1]);
    const row = this.coupleQuestions.find(
      (item) => item.id === id && item.coupleId === coupleId,
    );
    return row ? [{ id: row.id }] : [];
  };

  $transaction = async <T>(fn: (tx: MemoryDb) => Promise<T>): Promise<T> => {
    const run = this.mutex.then(() => fn(this));
    this.mutex = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  };
}

function asQueryId(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function seedQuestions(db: MemoryDb, count = 4) {
  for (let index = 0; index < count; index += 1) {
    db.questions.push({
      id: `q${index}`,
      slug: `fun-${String(index).padStart(3, '0')}`,
      text: `Pergunta ${index}`,
      locale: 'pt-BR',
      category: QuestionCategory.FUN,
      active: true,
    });
  }
}

describe('QuestionsService', () => {
  const couple = { id: 'couple-1', timezone: 'America/Sao_Paulo' };
  const other = { id: 'couple-2', timezone: 'America/Sao_Paulo' };
  const now = new Date('2026-10-05T15:00:00.000Z');

  function setup(count = 4) {
    const db = new MemoryDb();
    seedQuestions(db, count);
    const events: RecordActivityInput[] = [];
    const dailyPushes: Array<{ coupleId: string; coupleQuestionId: string }> =
      [];
    const activity = {
      record: async (input: RecordActivityInput) => {
        await Promise.resolve();
        events.push(input);
        return { id: `evt-${events.length}` };
      },
      pushDailyQuestion: async (input: {
        coupleId: string;
        coupleQuestionId: string;
      }) => {
        await Promise.resolve();
        dailyPushes.push(input);
      },
    } as unknown as ActivityService;
    const service = new QuestionsService(
      db as unknown as PrismaService,
      activity,
    );
    return { db, service, events, dailyPushes };
  }

  it('gives both partners one shared question when today is requested together', async () => {
    const { db, service } = setup();
    const [ada, bia] = await Promise.all([
      service.getToday('ada', couple, now),
      service.getToday('bia', couple, now),
    ]);
    expect(db.coupleQuestions).toHaveLength(1);
    expect(ada.id).toBe(bia.id);
    expect(ada.question.text).toBe(bia.question.text);
    expect(ada.date).toBe('2026-10-05');
  });

  it('hides the partner text until both have answered', async () => {
    const { service, events } = setup();
    const adaToday = await service.getToday('ada', couple, now);
    const afterAda = await service.answer(
      'ada',
      couple,
      adaToday.id,
      'segredo da ada',
      now,
    );
    expect(afterAda.partnerAnswered).toBe(false);
    expect(afterAda.myAnswer?.text).toBe('segredo da ada');
    expect(afterAda).not.toHaveProperty('partnerAnswer');

    const biaView = await service.getToday('bia', couple, now);
    expect(biaView.partnerAnswered).toBe(true);
    expect(biaView).not.toHaveProperty('partnerAnswer');
    expect(JSON.stringify(biaView)).not.toContain('segredo da ada');
    expect(events.map((event) => event.type)).toEqual([
      ActivityType.QUESTION_ANSWERED,
    ]);
    expect(events[0].push?.route).toBe('/question');
    expect(JSON.stringify(events[0].payload)).not.toContain('segredo da ada');

    const unlocked = await service.answer(
      'bia',
      couple,
      adaToday.id,
      'resposta da bia',
      now,
    );
    expect(unlocked.unlockedAt).toBeTruthy();
    expect(unlocked.myAnswer?.text).toBe('resposta da bia');
    expect(unlocked.partnerAnswer?.text).toBe('segredo da ada');

    const adaUnlocked = await service.getToday('ada', couple, now);
    expect(adaUnlocked.partnerAnswer?.text).toBe('resposta da bia');
    expect(events.map((event) => event.type)).toEqual([
      ActivityType.QUESTION_ANSWERED,
      ActivityType.QUESTION_UNLOCKED,
    ]);
    expect(events[1].actorId).toBe('bia');
  });

  it('allows an edit before unlock and rejects it after', async () => {
    const { service } = setup();
    const today = await service.getToday('ada', couple, now);
    const created = await service.answer(
      'ada',
      couple,
      today.id,
      'primeira',
      now,
    );
    const edited = await service.answer(
      'ada',
      couple,
      today.id,
      'editada',
      now,
    );
    expect(edited.myAnswer?.text).toBe('editada');
    expect(edited.myAnswer?.updatedAt).not.toBe(created.myAnswer?.updatedAt);

    await service.answer('bia', couple, today.id, 'fechou', now);
    await expect(
      service.answer('ada', couple, today.id, 'tarde demais', now),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects an 8-day-old question and unlocks a 6-day-old one', async () => {
    const { db, service } = setup();
    db.coupleQuestions.push(
      {
        id: 'old-8',
        coupleId: couple.id,
        questionId: 'q0',
        date: calendarDateToUtc('2026-09-27'),
        unlockedAt: null,
        dailyNotifiedAt: null,
        createdAt: now,
      },
      {
        id: 'old-6',
        coupleId: couple.id,
        questionId: 'q1',
        date: calendarDateToUtc('2026-09-29'),
        unlockedAt: null,
        dailyNotifiedAt: null,
        createdAt: now,
      },
    );

    await expect(
      service.answer('ada', couple, 'old-8', 'nao', now),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);

    await service.answer('ada', couple, 'old-6', 'ainda da', now);
    const unlocked = await service.answer(
      'bia',
      couple,
      'old-6',
      'tambem',
      now,
    );
    expect(unlocked.unlockedAt).toBeTruthy();
    expect(unlocked.partnerAnswer?.text).toBe('ainda da');
  });

  it('returns 404 for a couple question that belongs to someone else', async () => {
    const { service } = setup();
    const today = await service.getToday('ada', couple, now);
    await expect(
      service.answer('other', other, today.id, 'invasao', now),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('uses different questions on either side of local midnight', async () => {
    const { service } = setup();
    const before = await service.getToday(
      'ada',
      couple,
      new Date('2026-10-06T02:59:00.000Z'),
    );
    const after = await service.getToday(
      'ada',
      couple,
      new Date('2026-10-06T03:01:00.000Z'),
    );
    expect(before.date).toBe('2026-10-05');
    expect(after.date).toBe('2026-10-06');
    expect(before.id).not.toBe(after.id);
    expect(before.question.text).not.toBe(after.question.text);
  });

  it('logs a warning and reuses the least recent question when the bank is empty', async () => {
    const { service } = setup(1);
    const warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);
    const first = await service.getToday('ada', couple, now);
    const second = await service.getToday(
      'ada',
      couple,
      new Date('2026-10-06T15:00:00.000Z'),
    );
    expect(second.question.text).toBe(first.question.text);
    expect(second.date).toBe('2026-10-06');
    expect(
      warn.mock.calls.some((call) =>
        String(call[0]).includes('active question bank exhausted'),
      ),
    ).toBe(true);
    warn.mockRestore();
  });

  it('does not select partner answer text in history while locked', async () => {
    const { db, service } = setup();
    const today = await service.getToday('ada', couple, now);
    await service.answer('ada', couple, today.id, 'segredo da ada', now);
    db.reads.length = 0;
    const page = await service.history('bia', couple, { limit: 20 }, now);
    expect(page.items).toHaveLength(1);
    expect(page.items[0].partnerAnswered).toBe(true);
    expect(page.items[0]).not.toHaveProperty('partnerAnswer');
    expect(JSON.stringify(page)).not.toContain('segredo da ada');

    const textReads = db.reads.filter(
      (read) =>
        read.model === 'questionAnswer' && read.args.select?.text === true,
    );
    expect(textReads).toHaveLength(1);
    expect(textReads[0].args.where?.userId).toBe('bia');
  });

  it('sends the daily question push once', async () => {
    const { service, dailyPushes } = setup();
    const first = await service.deliverDailyQuestion(couple, now);
    const second = await service.deliverDailyQuestion(couple, now);
    expect(first.pushed).toBe(true);
    expect(second.pushed).toBe(false);
    expect(second.coupleQuestionId).toBe(first.coupleQuestionId);
    expect(dailyPushes).toHaveLength(1);
  });
});

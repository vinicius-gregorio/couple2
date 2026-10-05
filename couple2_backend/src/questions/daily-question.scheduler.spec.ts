import { PrismaService } from '../prisma';
import { DailyQuestionScheduler } from './daily-question.scheduler';
import { QuestionsService } from './questions.service';

describe('DailyQuestionScheduler', () => {
  it('delivers only for couples whose local hour is 10', async () => {
    const delivered: string[] = [];
    const questions = {
      deliverDailyQuestion: async (couple: { id: string }) => {
        await Promise.resolve();
        delivered.push(couple.id);
        return { coupleQuestionId: 'cq', pushed: true };
      },
    } as unknown as QuestionsService;
    const prisma = {
      couple: {
        findMany: async () => {
          await Promise.resolve();
          return [
            { id: 'sp', timezone: 'America/Sao_Paulo' },
            { id: 'az', timezone: 'America/Phoenix' },
          ];
        },
      },
    } as unknown as PrismaService;

    const scheduler = new DailyQuestionScheduler(prisma, questions);
    // 13:00 UTC is 10:00 in Sao Paulo and 06:00 in Phoenix.
    const result = await scheduler.run(new Date('2026-10-05T13:00:00.000Z'));

    expect(delivered).toEqual(['sp']);
    expect(result).toMatchObject({
      checked: 2,
      atLocalTen: 1,
      pushed: 1,
      skipped: 0,
    });
  });
});

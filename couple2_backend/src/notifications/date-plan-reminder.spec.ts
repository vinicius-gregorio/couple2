/* eslint-disable @typescript-eslint/require-await */
import { ActivityService } from './activity.service';
import type { PushSender } from './push-sender';
import { PrismaService } from '../prisma';

describe('pushDatePlanReminder', () => {
  it('sends one reminder to each partner and a second call still addresses both once', async () => {
    const sent: Array<{ tokens: string[]; data: { route: string } }> = [];
    const prisma = {
      couple: {
        findUnique: async () => ({
          id: 'couple-1',
          timezone: 'America/Sao_Paulo',
          userAId: 'user-a',
          userBId: 'user-b',
          status: 'ACTIVE',
        }),
      },
      notificationPreference: {
        findUnique: async () => null,
      },
      deviceToken: {
        findMany: async ({ where }: { where: { userId: string } }) => [
          { token: `token-${where.userId}` },
        ],
        deleteMany: async () => ({ count: 0 }),
      },
    } as unknown as PrismaService;
    const pushSender: PushSender = {
      send: async (message) => {
        sent.push({ tokens: message.tokens, data: message.data });
        return message.tokens.map((token) => ({ token, success: true }));
      },
    };
    const activity = new ActivityService(prisma, pushSender, {
      now: () => new Date('2026-10-05T15:00:00.000Z'),
    });

    await activity.pushDatePlanReminder({
      coupleId: 'couple-1',
      datePlanId: 'plan-1',
      title: 'Date em 2 horas',
      body: '"Japonês" é às 14:00',
    });

    expect(sent).toHaveLength(2);
    expect(sent.map((message) => message.tokens[0]).sort()).toEqual([
      'token-user-a',
      'token-user-b',
    ]);
    expect(
      sent.every((message) => message.data.route === '/dates/plan-1'),
    ).toBe(true);
  });
});

/* eslint-disable @typescript-eslint/require-await, @typescript-eslint/no-unsafe-assignment */
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  ActivityType,
  DatePlan,
  DatePlanStatus,
  ListType,
} from '@prisma/client';
import { ActivityService } from '../notifications/activity.service';
import type { RecordActivityInput } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import { DatePlansService } from './date-plans.service';

const now = new Date('2026-10-05T15:00:00.000Z');
const couple = { id: 'couple-1', timezone: 'America/Sao_Paulo' };
const userA = { id: 'user-a' };
const userB = { id: 'user-b' };

function row(overrides: Partial<DatePlan> = {}): DatePlan {
  return {
    id: 'plan-1',
    coupleId: couple.id,
    proposerId: userA.id,
    title: 'Japonês',
    description: null,
    location: 'Centro',
    scheduledAt: new Date('2026-10-09T23:00:00.000Z'),
    status: DatePlanStatus.PROPOSED,
    responseNote: null,
    respondedAt: null,
    completedAt: null,
    reminderSentAt: null,
    sourceListItemId: null,
    createdById: userA.id,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function serviceWith(prisma: PrismaService, recorded: RecordActivityInput[]) {
  const activity = {
    record: async (input: RecordActivityInput) => {
      recorded.push(input);
      return { id: 'event-1' };
    },
  } as unknown as ActivityService;
  return new DatePlansService(prisma, activity);
}

describe('DatePlansService', () => {
  it('proposes a date and pushes DATE_PLAN_PROPOSED to the partner', async () => {
    const recorded: RecordActivityInput[] = [];
    const created = row();
    const prisma = {
      datePlan: {
        create: async () => created,
      },
      listItem: { findMany: async () => [] },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, recorded);

    const view = await service.create(
      userA,
      couple,
      {
        title: 'Japonês',
        scheduledAt: '2026-10-09T20:00:00-03:00',
        location: 'Centro',
      },
      now,
    );

    expect(view.status).toBe(DatePlanStatus.PROPOSED);
    expect(view.proposerId).toBe(userA.id);
    expect(recorded).toHaveLength(1);
    expect(recorded[0]).toMatchObject({
      actorId: userA.id,
      type: ActivityType.DATE_PLAN_PROPOSED,
      push: { route: '/dates/plan-1' },
    });
    expect(recorded[0].payload?.whenLabel).toContain('20:00');
  });

  it('rejects the proposer accepting their own date', async () => {
    const recorded: RecordActivityInput[] = [];
    const updateMany = jest.fn();
    const prisma = {
      datePlan: {
        findFirst: async () => row(),
        updateMany,
      },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, recorded);

    await expect(
      service.accept(userA, couple, 'plan-1', now),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(updateMany).not.toHaveBeenCalled();
    expect(recorded).toHaveLength(0);
  });

  it('turns a counter into a new proposal owned by the partner', async () => {
    const recorded: RecordActivityInput[] = [];
    const countered = row({
      proposerId: userB.id,
      scheduledAt: new Date('2026-10-10T22:00:00.000Z'),
      responseNote: 'sábado',
      respondedAt: now,
    });
    const updateMany = jest.fn(async () => ({ count: 1 }));
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce(row())
      .mockResolvedValueOnce(countered);
    const prisma = {
      datePlan: { findFirst, updateMany },
      listItem: { findMany: async () => [] },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, recorded);

    const view = await service.counter(
      userB,
      couple,
      'plan-1',
      { scheduledAt: '2026-10-10T19:00:00-03:00', note: 'sábado' },
      now,
    );

    expect(view.proposerId).toBe(userB.id);
    expect(view.status).toBe(DatePlanStatus.PROPOSED);
    expect(view.scheduledAt.toISOString()).toBe('2026-10-10T22:00:00.000Z');
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'plan-1',
          coupleId: couple.id,
          status: DatePlanStatus.PROPOSED,
          proposerId: { not: userB.id },
        }) as unknown,
        data: expect.objectContaining({
          proposerId: userB.id,
          status: DatePlanStatus.PROPOSED,
        }) as unknown,
      }),
    );
    expect(recorded[0].type).toBe(ActivityType.DATE_PLAN_COUNTERED);

    findFirst.mockResolvedValue(countered);
    await expect(
      service.accept(userB, couple, 'plan-1', now),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('returns 409 when accept loses the race to cancel', async () => {
    const recorded: RecordActivityInput[] = [];
    const updateMany = jest.fn(async () => ({ count: 0 }));
    const prisma = {
      datePlan: {
        findFirst: async () => row(),
        updateMany,
      },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, recorded);

    await expect(
      service.accept(userB, couple, 'plan-1', now),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: DatePlanStatus.PROPOSED }),
      }),
    );
    expect(recorded).toHaveLength(0);
  });

  it('returns 409 when cancel loses the race to accept', async () => {
    const updateMany = jest.fn(async () => ({ count: 0 }));
    const prisma = {
      datePlan: {
        findFirst: async () => row(),
        updateMany,
      },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, []);

    await expect(
      service.cancel(userA, couple, 'plan-1', {}, now),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('refuses done a day early and records completedAt once the time has come', async () => {
    const recorded: RecordActivityInput[] = [];
    const accepted = row({
      status: DatePlanStatus.ACCEPTED,
      scheduledAt: new Date(now.getTime() + 24 * 60 * 60 * 1000),
    });
    const updateMany = jest.fn();
    const prisma = {
      datePlan: {
        findFirst: async () => accepted,
        updateMany,
      },
    } as unknown as PrismaService;
    const service = serviceWith(prisma, recorded);

    await expect(
      service.done(userA, couple, 'plan-1', now),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(updateMany).not.toHaveBeenCalled();

    const readyAt = new Date('2026-10-09T23:30:00.000Z');
    const ready = row({
      status: DatePlanStatus.ACCEPTED,
      scheduledAt: new Date('2026-10-09T23:00:00.000Z'),
    });
    const finished = row({
      status: DatePlanStatus.DONE,
      scheduledAt: ready.scheduledAt,
      completedAt: readyAt,
    });
    const readyUpdate = jest.fn(async () => ({ count: 1 }));
    const readyPrisma = {
      datePlan: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce(ready)
          .mockResolvedValueOnce(finished),
        updateMany: readyUpdate,
      },
      listItem: { findMany: async () => [] },
    } as unknown as PrismaService;
    const readyService = serviceWith(readyPrisma, recorded);
    const view = await readyService.done(userB, couple, 'plan-1', readyAt);

    expect(view.status).toBe(DatePlanStatus.DONE);
    expect(view.completedAt).toEqual(readyAt);
    expect(readyUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: DatePlanStatus.DONE, completedAt: readyAt },
      }),
    );
    expect(recorded[0].type).toBe(ActivityType.DATE_PLAN_DONE);
  });

  it('rejects a source item from another couple or a shopping list', async () => {
    const create = jest.fn();
    const cases = [
      { coupleId: 'couple-2', type: ListType.MOVIES },
      { coupleId: couple.id, type: ListType.SHOPPING_CART },
    ];
    for (const list of cases) {
      const prisma = {
        listItem: {
          findUnique: async () => ({ id: 'item-1', list }),
        },
        datePlan: { create },
      } as unknown as PrismaService;
      const service = serviceWith(prisma, []);
      await expect(
        service.create(
          userA,
          couple,
          {
            title: 'Filme',
            scheduledAt: '2026-10-09T20:00:00-03:00',
            sourceListItemId: 'item-1',
          },
          now,
        ),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    }
    expect(create).not.toHaveBeenCalled();
  });

  it('rejects a scheduledAt in the past', async () => {
    const service = serviceWith({} as PrismaService, []);
    await expect(
      service.create(
        userA,
        couple,
        { title: 'Japonês', scheduledAt: '2020-01-01T20:00:00.000Z' },
        now,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

/* eslint-disable @typescript-eslint/require-await */
import { ExecutionContext, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { DatePlanStatus } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { DatePlansController } from './date-plans.controller';
import { DatePlanGuard } from './guards/date-plan.guard';

describe('DatePlanGuard', () => {
  const plan = {
    id: 'plan-1',
    coupleId: 'couple-1',
    status: DatePlanStatus.PROPOSED,
  };

  function contextFor(
    user: { id: string; coupleId: string | null },
    found: typeof plan | null,
  ) {
    const request: {
      user: typeof user;
      params: { id: string };
      datePlan?: typeof plan;
    } = { user, params: { id: 'plan-1' } };
    const prisma = {
      datePlan: {
        findUnique: async () => found,
      },
    };
    return {
      guard: new DatePlanGuard(prisma as never),
      context: {
        switchToHttp: () => ({ getRequest: () => request }),
      } as ExecutionContext,
      request,
    };
  }

  it('returns 404 when the date belongs to another couple', async () => {
    const { guard, context } = contextFor(
      { id: 'stranger', coupleId: 'couple-2' },
      plan,
    );
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns 404 when the date does not exist', async () => {
    const { guard, context } = contextFor(
      { id: 'user-a', coupleId: 'couple-1' },
      null,
    );
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('attaches the date when it belongs to the caller couple', async () => {
    const { guard, context, request } = contextFor(
      { id: 'user-a', coupleId: 'couple-1' },
      plan,
    );
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.datePlan).toBe(plan);
  });
});

describe('date plan routes', () => {
  const actionNames = [
    'get',
    'update',
    'accept',
    'decline',
    'counter',
    'cancel',
    'done',
  ];

  it('requires the couple and the date plan guard on :id actions', () => {
    const controllerGuards = Reflect.getMetadata(
      GUARDS_METADATA,
      DatePlansController,
    ) as unknown[];
    expect(controllerGuards).toContain(JwtAuthGuard);
    expect(controllerGuards).toContain(CoupleGuard);

    for (const name of actionNames) {
      const handler = Object.getOwnPropertyDescriptor(
        DatePlansController.prototype,
        name,
      )?.value as object;
      const guards = Reflect.getMetadata(GUARDS_METADATA, handler) as unknown[];
      expect(guards).toContain(DatePlanGuard);
    }
  });
});

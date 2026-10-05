import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { JwtAuthGuard } from '../auth/guards';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { IgnoreClientReceiverGuard } from './ignore-client-receiver.guard';
import { MoodController } from './mood.controller';
import { NudgesController } from './nudges.controller';

describe('mood routes require a couple', () => {
  function contextFor(user: object | undefined): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as ExecutionContext;
  }

  it('returns 403 when the user has no couple', async () => {
    const guard = new CoupleGuard({} as never);
    await expect(
      guard.canActivate(
        contextFor({ id: 'solo', partnerId: null, coupleId: null }),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('puts JwtAuthGuard and CoupleGuard on every mood and nudge route', () => {
    for (const controller of [MoodController, NudgesController]) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        controller,
      ) as unknown[];
      expect(guards).toContain(JwtAuthGuard);
      expect(guards).toContain(CoupleGuard);
    }
    const create = Object.getOwnPropertyDescriptor(
      NudgesController.prototype,
      'create',
    )?.value as object;
    const createGuards = Reflect.getMetadata(
      GUARDS_METADATA,
      create,
    ) as unknown[];
    expect(createGuards).toContain(IgnoreClientReceiverGuard);
  });
});

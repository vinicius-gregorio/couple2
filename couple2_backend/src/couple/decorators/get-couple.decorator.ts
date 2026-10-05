import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Couple } from '@prisma/client';

interface RequestWithCouple {
  couple?: Couple;
}

/**
 * Couple loaded by CoupleGuard. Use only on routes that include that guard.
 */
export const GetCouple = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): Couple => {
    const request = ctx.switchToHttp().getRequest<RequestWithCouple>();
    return request.couple as Couple;
  },
);

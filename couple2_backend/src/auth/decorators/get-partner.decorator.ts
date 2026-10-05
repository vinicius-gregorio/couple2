import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { User } from '@prisma/client';
import type { UserWithPartner } from '../strategies/jwt.strategy';

type PartnerInfo = Pick<User, 'id' | 'name' | 'email'> | null;

interface RequestWithUser {
  user?: UserWithPartner;
}

/**
 * Custom decorator to extract the authenticated user's partner from the request.
 * Returns null if the user is not paired.
 *
 * @example
 * @UseGuards(JwtAuthGuard, PairingGuard)
 * @Get('partner')
 * async getPartner(@GetPartner() partner: PartnerInfo) {
 *   return partner;
 * }
 */
export const GetPartner = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): PartnerInfo => {
    const request = ctx.switchToHttp().getRequest<RequestWithUser>();
    return request.user?.partner ?? null;
  },
);

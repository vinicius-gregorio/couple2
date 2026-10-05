import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { UserWithPartner } from '../strategies/jwt.strategy';

interface RequestWithUser {
  user: UserWithPartner;
}

/**
 * Custom decorator to extract the authenticated user from the request.
 * Use this instead of @Req() to get type-safe access to the user.
 *
 * @example
 * @UseGuards(JwtAuthGuard)
 * @Get('profile')
 * async getProfile(@GetUser() user: UserWithPartner) {
 *   return user;
 * }
 */
export const GetUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): UserWithPartner => {
    const request = ctx.switchToHttp().getRequest<RequestWithUser>();
    return request.user;
  },
);

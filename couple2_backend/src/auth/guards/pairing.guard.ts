import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import type { UserWithPartner } from '../strategies/jwt.strategy';

export const PAIRING_REQUIRED_MESSAGE =
  'This feature requires you to be paired with a partner';

interface RequestWithUser {
  user?: UserWithPartner;
}

/**
 * Guard that ensures the user is paired with a partner.
 * Must be used AFTER JwtAuthGuard to ensure user is authenticated.
 *
 * @example
 * @UseGuards(JwtAuthGuard, PairingGuard)
 * @Get('couple-only')
 * async coupleOnlyRoute(@GetUser() user: UserWithPartner) {
 *   // Only paired users can access this route
 * }
 */
@Injectable()
export class PairingGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User not authenticated');
    }

    if (!user.partnerId) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }

    return true;
  }
}

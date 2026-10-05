import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import type { Couple } from '@prisma/client';
import { PAIRING_REQUIRED_MESSAGE } from '../../auth/guards/pairing.guard';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';
import { PrismaService } from '../../prisma';

interface RequestWithUserAndCouple {
  user?: UserWithPartner;
  couple?: Couple;
}

/**
 * Requires an active couple. partnerId and coupleId are written together;
 * either one missing means the user is not paired.
 */
@Injectable()
export class CoupleGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<RequestWithUserAndCouple>();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User not authenticated');
    }

    if (!user.partnerId || !user.coupleId) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }

    const couple = await this.prisma.couple.findFirst({
      where: {
        id: user.coupleId,
        status: 'ACTIVE',
        OR: [{ userAId: user.id }, { userBId: user.id }],
      },
    });

    if (!couple) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }

    request.couple = couple;
    return true;
  }
}

import {
  Injectable,
  CanActivate,
  ExecutionContext,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';
import { listAccessWhere } from '../list-access';

interface RequestWithUser {
  user: UserWithPartner;
  params: { id: string };
}

@Injectable()
export class SharedListGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const user = request.user;
    const listId = request.params.id;

    // 404 for a missing list, another couple, an ENDED couple, and a
    // partner's PRIVATE_FROM_PARTNER list. 403 would admit the list exists.
    const list = await this.prisma.partnerList.findFirst({
      where: { id: listId, AND: [listAccessWhere(user)] },
    });

    if (!list) {
      throw new NotFoundException('List not found');
    }

    return true;
  }
}

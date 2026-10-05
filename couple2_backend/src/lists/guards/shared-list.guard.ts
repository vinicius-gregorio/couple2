import {
  Injectable,
  CanActivate,
  ExecutionContext,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';

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

    const list = await this.prisma.partnerList.findUnique({
      where: { id: listId },
    });

    // 404 for missing lists and for lists that belong to another couple,
    // including an ENDED couple this user used to share.
    if (!list || !user.coupleId || list.coupleId !== user.coupleId) {
      throw new NotFoundException('List not found');
    }

    return true;
  }
}

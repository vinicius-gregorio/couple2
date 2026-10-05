import {
  CanActivate,
  ExecutionContext,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';
import { PrismaService } from '../../prisma';

interface RequestWithUser {
  user: UserWithPartner;
  params: { id: string };
}

/**
 * Resolves a list item to its list and requires list.coupleId === user.coupleId.
 * Missing items and items from another couple are both 404.
 */
@Injectable()
export class SharedListItemGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const user = request.user;
    const itemId = request.params.id;

    const item = await this.prisma.listItem.findUnique({
      where: { id: itemId },
      include: { list: true },
    });

    if (!item || !user.coupleId || item.list.coupleId !== user.coupleId) {
      throw new NotFoundException('Item not found');
    }

    return true;
  }
}

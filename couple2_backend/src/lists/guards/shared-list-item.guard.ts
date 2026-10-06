import {
  CanActivate,
  ExecutionContext,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';
import { PrismaService } from '../../prisma';
import { listAccessWhere } from '../list-access';

interface RequestWithUser {
  user: UserWithPartner;
  params: { id: string };
}

/**
 * Resolves a list item through listAccessWhere.
 * Missing items, another couple, and a partner's private list are all 404.
 */
@Injectable()
export class SharedListItemGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const user = request.user;
    const itemId = request.params.id;

    const item = await this.prisma.listItem.findFirst({
      where: { id: itemId, list: listAccessWhere(user) },
    });

    if (!item) {
      throw new NotFoundException('Item not found');
    }

    return true;
  }
}

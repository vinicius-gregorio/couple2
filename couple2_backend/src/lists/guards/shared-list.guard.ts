import {
  Injectable,
  CanActivate,
  ExecutionContext,
  NotFoundException,
  ForbiddenException,
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

    if (!list) throw new NotFoundException('List not found');

    const isOwner = list.ownerId === user.id;
    const isPartner = list.ownerId === user.partnerId;

    if (!isOwner && !isPartner) {
      throw new ForbiddenException('You do not have access to this list');
    }

    return true;
  }
}

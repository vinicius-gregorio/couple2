import { ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { CLOCK, type Clock } from './clock';
import {
  buildFeedWhere,
  decodeFeedCursor,
  encodeFeedCursor,
} from './feed-cursor';

export interface FeedQuery {
  cursor?: string;
  limit?: number;
}

@Injectable()
export class FeedService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async list(user: UserWithPartner, query: FeedQuery) {
    const coupleId = this.coupleId(user);
    const limit = query.limit ?? 20;
    const cursor = query.cursor ? decodeFeedCursor(query.cursor) : null;
    const rows = await this.prisma.activityEvent.findMany({
      where: buildFeedWhere(coupleId, cursor),
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const last = items[items.length - 1];
    return {
      items,
      nextCursor: hasMore && last ? encodeFeedCursor(last) : null,
    };
  }

  /**
   * Partner events newer than feedSeenAt. System rows (actorId null) and the
   * viewer's own rows are not unread. A null cursor means the feed was never
   * opened, so every partner event counts.
   */
  async unreadCount(user: UserWithPartner) {
    const coupleId = this.coupleId(user);
    if (!user.partnerId) {
      return { count: 0 };
    }
    const count = await this.prisma.activityEvent.count({
      where: {
        coupleId,
        actorId: user.partnerId,
        ...(user.feedSeenAt ? { createdAt: { gt: user.feedSeenAt } } : {}),
      },
    });
    return { count };
  }

  async markSeen(userId: string) {
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { feedSeenAt: this.clock.now() },
      select: { feedSeenAt: true },
    });
    return { feedSeenAt: updated.feedSeenAt };
  }

  private coupleId(user: UserWithPartner): string {
    if (!user.coupleId) {
      throw new ForbiddenException('Pairing required');
    }
    return user.coupleId;
  }
}

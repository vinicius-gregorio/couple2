import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ActivityType, NudgeKind } from '@prisma/client';
import { PAIRING_REQUIRED_MESSAGE } from '../auth/guards/pairing.guard';
import { ActivityService } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import type { MoodActor, MoodCouple } from './mood.service';
import {
  NUDGE_COLLAPSE_KEY,
  NUDGE_COLLAPSE_WINDOW_MS,
  NUDGE_HOURLY_LIMIT,
  NUDGE_ROUTE,
  NUDGE_WINDOW_MS,
  RECEIVED_NUDGES_DEFAULT_LIMIT,
  nudgeRetryAfterSeconds,
} from './mood-policy';
import {
  buildReceivedNudgeWhere,
  decodeNudgeCursor,
  encodeNudgeCursor,
} from './nudge-cursor';

export interface NudgeView {
  id: string;
  senderId: string;
  receiverId: string;
  kind: NudgeKind;
  message: string | null;
  seenAt: Date | null;
  createdAt: Date;
}

@Injectable()
export class NudgesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  async create(
    user: MoodActor,
    couple: MoodCouple,
    input: { kind: NudgeKind; message?: string },
    now = new Date(),
  ): Promise<NudgeView> {
    if (!user.partnerId) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }
    const receiverId = user.partnerId;
    const since = new Date(now.getTime() - NUDGE_WINDOW_MS);

    const created = await this.prisma.$transaction(async (tx) => {
      const recent = await tx.nudge.findMany({
        where: { senderId: user.id, createdAt: { gt: since } },
        orderBy: { createdAt: 'asc' },
        select: { createdAt: true },
      });
      if (recent.length >= NUDGE_HOURLY_LIMIT) {
        const retryAfter = nudgeRetryAfterSeconds(recent[0].createdAt, now);
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            message: 'Muitos carinhos nesta hora',
            error: 'Too Many Requests',
            retryAfter,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      return tx.nudge.create({
        data: {
          coupleId: couple.id,
          senderId: user.id,
          receiverId,
          kind: input.kind,
          message: input.message ?? null,
          createdAt: now,
        },
      });
    });

    const collapseSince = new Date(now.getTime() - NUDGE_COLLAPSE_WINDOW_MS);
    const recentCount = await this.prisma.nudge.count({
      where: { senderId: user.id, createdAt: { gt: collapseSince } },
    });

    await this.activity.record({
      coupleId: couple.id,
      actorId: user.id,
      type: ActivityType.NUDGE_SENT,
      entity: { type: 'Nudge', id: created.id },
      payload: {
        kind: created.kind,
        recentCount,
        ...(created.message ? { message: created.message } : {}),
      },
      push: { route: NUDGE_ROUTE, collapseKey: NUDGE_COLLAPSE_KEY },
    });

    return this.toView(created);
  }

  async received(
    user: MoodActor,
    couple: MoodCouple,
    query: { cursor?: string; limit?: number },
  ): Promise<{ items: NudgeView[]; nextCursor: string | null }> {
    if (!user.partnerId) {
      throw new ForbiddenException(PAIRING_REQUIRED_MESSAGE);
    }
    const limit = query.limit ?? RECEIVED_NUDGES_DEFAULT_LIMIT;
    const cursor = query.cursor ? decodeNudgeCursor(query.cursor) : null;
    const rows = await this.prisma.nudge.findMany({
      where: buildReceivedNudgeWhere(couple.id, user.id, cursor),
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page[page.length - 1];
    return {
      items: page.map((row) => this.toView(row)),
      nextCursor:
        hasMore && last
          ? encodeNudgeCursor({ createdAt: last.createdAt, id: last.id })
          : null,
    };
  }

  /**
   * Only the receiver can mark a nudge seen. The sender, and any other
   * couple, get the same 404 — the id is not confirmed.
   */
  async markSeen(
    user: MoodActor,
    couple: MoodCouple,
    id: string,
    now = new Date(),
  ): Promise<NudgeView> {
    const row = await this.prisma.nudge.findFirst({
      where: { id, coupleId: couple.id, receiverId: user.id },
    });
    if (!row) throw new NotFoundException('Nudge not found');
    if (row.seenAt) return this.toView(row);
    const updated = await this.prisma.nudge.update({
      where: { id: row.id },
      data: { seenAt: now },
    });
    return this.toView(updated);
  }

  private toView(row: {
    id: string;
    senderId: string;
    receiverId: string;
    kind: NudgeKind;
    message: string | null;
    seenAt: Date | null;
    createdAt: Date;
  }): NudgeView {
    return {
      id: row.id,
      senderId: row.senderId,
      receiverId: row.receiverId,
      kind: row.kind,
      message: row.message,
      seenAt: row.seenAt,
      createdAt: row.createdAt,
    };
  }
}

import { Prisma } from '@prisma/client';
import {
  decodeFeedCursor,
  encodeFeedCursor,
  type FeedCursor,
} from '../notifications/feed-cursor';

export function encodeNudgeCursor(item: FeedCursor): string {
  return encodeFeedCursor(item);
}

export function decodeNudgeCursor(cursor: string): FeedCursor {
  return decodeFeedCursor(cursor);
}

/** Received nudges for one person, newest first, scoped to the couple. */
export function buildReceivedNudgeWhere(
  coupleId: string,
  receiverId: string,
  cursor: FeedCursor | null,
): Prisma.NudgeWhereInput {
  const base: Prisma.NudgeWhereInput = { coupleId, receiverId };
  if (!cursor) return base;
  return {
    ...base,
    OR: [
      { createdAt: { lt: cursor.createdAt } },
      { AND: [{ createdAt: cursor.createdAt }, { id: { lt: cursor.id } }] },
    ],
  };
}

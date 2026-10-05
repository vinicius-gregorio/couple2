import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

export interface FeedCursor {
  createdAt: Date;
  id: string;
}

export function encodeFeedCursor(item: FeedCursor): string {
  return Buffer.from(
    `${item.createdAt.toISOString()}|${item.id}`,
    'utf8',
  ).toString('base64url');
}

export function decodeFeedCursor(cursor: string): FeedCursor {
  let raw: string;
  try {
    raw = Buffer.from(cursor, 'base64url').toString('utf8');
  } catch {
    throw new BadRequestException('Invalid cursor');
  }
  const separator = raw.indexOf('|');
  if (separator <= 0) throw new BadRequestException('Invalid cursor');
  const createdAt = new Date(raw.slice(0, separator));
  const id = raw.slice(separator + 1);
  if (Number.isNaN(createdAt.getTime()) || id.length === 0) {
    throw new BadRequestException('Invalid cursor');
  }
  return { createdAt, id };
}

/** Keyset page on (createdAt desc, id desc), scoped to one couple. */
export function buildFeedWhere(
  coupleId: string,
  cursor: FeedCursor | null,
): Prisma.ActivityEventWhereInput {
  if (!cursor) return { coupleId };
  return {
    coupleId,
    OR: [
      { createdAt: { lt: cursor.createdAt } },
      { AND: [{ createdAt: cursor.createdAt }, { id: { lt: cursor.id } }] },
    ],
  };
}

export function isBeforeCursor(item: FeedCursor, cursor: FeedCursor): boolean {
  const itemTime = item.createdAt.getTime();
  const cursorTime = cursor.createdAt.getTime();
  if (itemTime < cursorTime) return true;
  if (itemTime === cursorTime && item.id < cursor.id) return true;
  return false;
}

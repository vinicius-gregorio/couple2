import { BadRequestException } from '@nestjs/common';
import {
  buildFeedWhere,
  decodeFeedCursor,
  encodeFeedCursor,
  isBeforeCursor,
} from './feed-cursor';

describe('feed cursor', () => {
  const newer = { createdAt: new Date('2026-10-05T12:00:00.000Z'), id: 'b' };
  const sameTimeLowerId = {
    createdAt: new Date('2026-10-05T12:00:00.000Z'),
    id: 'a',
  };
  const older = { createdAt: new Date('2026-10-05T11:00:00.000Z'), id: 'c' };

  it('round-trips and rejects garbage', () => {
    const encoded = encodeFeedCursor(newer);
    expect(decodeFeedCursor(encoded)).toEqual(newer);
    expect(() => decodeFeedCursor('@@@')).toThrow(BadRequestException);
    expect(() =>
      decodeFeedCursor(Buffer.from('nope', 'utf8').toString('base64url')),
    ).toThrow(BadRequestException);
  });

  it('pages (createdAt, id) descending without repeating the cursor item', () => {
    const items = [newer, sameTimeLowerId, older];
    const firstPage = items.filter(() => true).slice(0, 2);
    const cursor = firstPage[firstPage.length - 1];
    const secondPage = items.filter((item) => isBeforeCursor(item, cursor));

    expect(firstPage.map((item) => item.id)).toEqual(['b', 'a']);
    expect(secondPage.map((item) => item.id)).toEqual(['c']);
    expect(secondPage.some((item) => firstPage.includes(item))).toBe(false);

    const where = buildFeedWhere('couple-1', cursor);
    expect(where.coupleId).toBe('couple-1');
    expect(where.OR).toHaveLength(2);
  });
});

import { readFileSync } from 'fs';
import { join } from 'path';

describe('question seed migration', () => {
  const sql = readFileSync(
    join(
      __dirname,
      '../../prisma/migrations/20261005230000_add_daily_question/migration.sql',
    ),
    'utf8',
  );

  it('inserts at least 120 unique slugs and is safe to run twice', () => {
    expect(sql).toContain('ON CONFLICT ("slug") DO NOTHING');
    expect(sql).not.toMatch(/DELETE\s+FROM\s+"questions"/i);

    const slugs = [
      ...sql.matchAll(/'((?:fun|memories|future|daily|deep)-\d{3})'/g),
    ].map((match) => match[1]);
    expect(slugs.length).toBeGreaterThanOrEqual(120);
    expect(new Set(slugs).size).toBe(slugs.length);

    const categories = [
      ...sql.matchAll(/'(FUN|DEEP|MEMORIES|FUTURE|DAILY_LIFE)'/g),
    ].map((match) => match[1]);
    expect(new Set(categories)).toEqual(
      new Set(['FUN', 'DEEP', 'MEMORIES', 'FUTURE', 'DAILY_LIFE']),
    );
    const deep = categories.filter((category) => category === 'DEEP').length;
    const nonDeep = categories.length - deep;
    expect(nonDeep).toBeGreaterThanOrEqual(120);
  });
});

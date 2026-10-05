/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-argument, @typescript-eslint/require-await */
import { HttpException, NotFoundException } from '@nestjs/common';
import {
  ActivityType,
  DevicePlatform,
  MoodLevel,
  NudgeKind,
} from '@prisma/client';
import { ActivityService } from '../notifications/activity.service';
import type { Clock } from '../notifications/clock';
import type {
  PushMessage,
  PushSender,
  PushSendResult,
} from '../notifications/push-sender';
import { MoodService } from './mood.service';
import { NudgesService } from './nudges.service';

interface Row {
  id: string;
  createdAt: Date;
  [key: string]: unknown;
}

class RecordingPushSender implements PushSender {
  readonly sent: PushMessage[] = [];

  async send(message: PushMessage): Promise<PushSendResult[]> {
    this.sent.push(message);
    return message.tokens.map((token) => ({ token, success: true }));
  }
}

function matches(row: Record<string, unknown>, where: any): boolean {
  if (!where) return true;
  for (const key of Object.keys(where)) {
    const expected = where[key];
    if (key === 'OR') {
      if (!expected.some((branch: any) => matches(row, branch))) return false;
      continue;
    }
    if (key === 'AND') {
      if (!expected.every((part: any) => matches(row, part))) return false;
      continue;
    }
    const actual = row[key];
    if (expected instanceof Date) {
      if (
        !(actual instanceof Date) ||
        actual.getTime() !== expected.getTime()
      ) {
        return false;
      }
      continue;
    }
    if (expected && typeof expected === 'object') {
      if ('gt' in expected && !(actual > expected.gt)) return false;
      if ('gte' in expected && !(actual >= expected.gte)) return false;
      if ('lt' in expected && !(actual < expected.lt)) return false;
      if (expected.in && !expected.in.includes(actual)) return false;
      continue;
    }
    if (actual !== expected) return false;
  }
  return true;
}

function project(
  row: Record<string, unknown>,
  select?: Record<string, boolean>,
) {
  if (!select) return row;
  const out: Record<string, unknown> = {};
  for (const key of Object.keys(select)) {
    if (select[key]) out[key] = row[key];
  }
  return out;
}

function ordered(rows: Row[], orderBy: any): Row[] {
  if (!orderBy) return rows;
  const orders = Array.isArray(orderBy) ? orderBy : [orderBy];
  return [...rows].sort((a, b) => {
    for (const order of orders) {
      const key = Object.keys(order)[0];
      const dir = order[key] === 'asc' ? 1 : -1;
      const av = a[key];
      const bv = b[key];
      if (av instanceof Date && bv instanceof Date) {
        const cmp = av.getTime() - bv.getTime();
        if (cmp !== 0) return cmp * dir;
      } else if (av < bv) return -1 * dir;
      else if (av > bv) return 1 * dir;
    }
    return 0;
  });
}

function harness(initial = new Date('2026-10-05T15:00:00.000Z')) {
  const clock = { now: initial };
  const checkins: Row[] = [];
  const nudges: Row[] = [];
  const events: Row[] = [];
  const tokens: Row[] = [];
  const users = new Map<string, { id: string; name: string }>();
  const prefs = new Map<string, Record<string, unknown>>();
  let seq = 0;
  const next = (prefix: string) => {
    seq += 1;
    return `${prefix}-${seq}`;
  };

  const couple = {
    id: 'couple-1',
    userAId: 'ada',
    userBId: 'bob',
    status: 'ACTIVE',
    timezone: 'America/Sao_Paulo',
  };
  users.set('ada', { id: 'ada', name: 'Ada' });
  users.set('bob', { id: 'bob', name: 'Bob' });

  function collection(rows: Row[], prefix: string) {
    return {
      create: async ({ data }: any) => {
        const row: Row = {
          id: data.id ?? next(prefix),
          createdAt: data.createdAt
            ? new Date(data.createdAt)
            : new Date(clock.now),
          note: null,
          message: null,
          seenAt: null,
          ...data,
        };
        rows.push(row);
        return row;
      },
      findFirst: async ({ where, orderBy, select }: any) => {
        const found = ordered(
          rows.filter((row) => matches(row, where)),
          orderBy,
        )[0];
        return found ? project(found, select) : null;
      },
      findMany: async ({ where, orderBy, take, select }: any) => {
        let found = ordered(
          rows.filter((row) => matches(row, where)),
          orderBy,
        );
        if (take) found = found.slice(0, take);
        return found.map((row) => project(row, select));
      },
      count: async ({ where }: any) =>
        rows.filter((row) => matches(row, where)).length,
      update: async ({ where, data }: any) => {
        const row = rows.find((item) => item.id === where.id);
        if (!row) throw new Error('row missing');
        Object.assign(row, data);
        return row;
      },
    };
  }

  const prisma: any = {
    moodCheckin: collection(checkins, 'mood'),
    nudge: collection(nudges, 'nudge'),
    activityEvent: {
      create: async ({ data }: any) => {
        const row: Row = {
          id: next('evt'),
          createdAt: new Date(clock.now),
          payload: data.payload ?? null,
          ...data,
        };
        events.push(row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = events.find((event) => event.id === where.id);
        if (!row) throw new Error('event missing');
        Object.assign(row, data);
        return row;
      },
      findMany: async ({ where, select }: any) =>
        events
          .filter((event) => matches(event, where))
          .map((event) => project(event, select)),
    },
    couple: {
      findUnique: async ({ where, select }: any) => {
        if (where.id !== couple.id) return null;
        return project(couple, select);
      },
    },
    user: {
      findUnique: async ({ where, select }: any) => {
        const row = users.get(where.id);
        if (!row) return null;
        return project(row, select);
      },
    },
    notificationPreference: {
      findUnique: async ({ where }: any) => prefs.get(where.userId) ?? null,
    },
    deviceToken: {
      findMany: async ({ where }: any) =>
        tokens.filter((token) => matches(token, where)),
      deleteMany: async () => ({ count: 0 }),
    },
  };
  prisma.$transaction = async (fn: (tx: typeof prisma) => Promise<unknown>) =>
    fn(prisma);

  const sender = new RecordingPushSender();
  const time: Clock = { now: () => clock.now };
  const activity = new ActivityService(prisma, sender, time);
  const mood = new MoodService(prisma, activity);
  const nudgesService = new NudgesService(prisma, activity);

  return {
    clock,
    checkins,
    nudges,
    events,
    tokens,
    prefs,
    sender,
    mood,
    nudgesService,
    couple: { id: couple.id },
    ada: { id: 'ada', partnerId: 'bob' },
    bob: { id: 'bob', partnerId: 'ada' },
  };
}

function addToken(h: ReturnType<typeof harness>, userId: string) {
  h.tokens.push({
    id: `tok-${userId}`,
    userId,
    token: `token-${userId}`,
    platform: DevicePlatform.IOS,
    createdAt: h.clock.now,
  });
}

describe('mood check-in and nudge', () => {
  it('keeps the latest mood and both check-ins from the same day', async () => {
    const h = harness();
    const morning = new Date('2026-10-05T12:00:00.000Z');
    const afternoon = new Date('2026-10-05T18:00:00.000Z');
    h.clock.now = morning;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.GOOD }, morning);
    h.clock.now = afternoon;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.LOW }, afternoon);

    const current = await h.mood.current(h.bob, h.couple, afternoon);
    expect(current.partner?.mood).toBe(MoodLevel.LOW);
    expect(current.partner?.stale).toBe(false);
    expect(current.me).toBeNull();

    const history = await h.mood.history(
      h.bob,
      h.couple,
      { days: 30 },
      afternoon,
    );
    expect(history.items).toHaveLength(2);
    expect(history.items.map((item) => item.mood)).toEqual([
      MoodLevel.LOW,
      MoodLevel.GOOD,
    ]);
  });

  it('pushes LOW once per 6 hours and never pushes GREAT, GOOD, or OK', async () => {
    const h = harness();
    addToken(h, 'bob');
    const note = 'segredo doloroso';
    const first = new Date('2026-10-05T15:00:00.000Z');
    h.clock.now = first;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.LOW, note }, first);

    const second = new Date('2026-10-05T15:40:00.000Z');
    h.clock.now = second;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.LOW, note }, second);

    for (const mood of [MoodLevel.GREAT, MoodLevel.GOOD, MoodLevel.OK]) {
      h.clock.now = new Date(h.clock.now.getTime() + 60_000);
      await h.mood.create(h.ada, h.couple, { mood }, h.clock.now);
    }

    const moodPushes = h.sender.sent.filter(
      (message) => message.data.type === ActivityType.MOOD_SHARED,
    );
    expect(moodPushes).toHaveLength(1);
    expect(moodPushes[0].notification.body).toBe(
      'Ada não está num dia muito bom 💛',
    );
    expect(moodPushes[0].notification.body).not.toContain('segredo');
    expect(moodPushes[0].data.route).toBe('/mood/history');
    expect(
      h.events
        .filter((event) => event.type === ActivityType.MOOD_SHARED)
        .every((event) => {
          const payload = event.payload as Record<string, unknown>;
          return (
            payload.note == null && !JSON.stringify(payload).includes(note)
          );
        }),
    ).toBe(true);

    const later = new Date(first.getTime() + 6 * 60 * 60 * 1000 + 1000);
    h.clock.now = later;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.BAD }, later);
    expect(
      h.sender.sent.filter(
        (message) => message.data.type === ActivityType.MOOD_SHARED,
      ),
    ).toHaveLength(2);
  });

  it('marks a check-in stale after 24 hours', async () => {
    const h = harness();
    const at = new Date('2026-10-05T15:00:00.000Z');
    h.clock.now = at;
    await h.mood.create(h.ada, h.couple, { mood: MoodLevel.OK }, at);
    const exact = await h.mood.current(
      h.bob,
      h.couple,
      new Date(at.getTime() + 24 * 60 * 60 * 1000),
    );
    expect(exact.partner?.stale).toBe(false);
    const after = await h.mood.current(
      h.bob,
      h.couple,
      new Date(at.getTime() + 24 * 60 * 60 * 1000 + 1),
    );
    expect(after.partner?.stale).toBe(true);
  });

  it('rejects the 11th nudge in an hour with retryAfter and writes nothing', async () => {
    const h = harness();
    addToken(h, 'bob');
    const start = new Date('2026-10-05T15:00:00.000Z');
    for (let i = 0; i < 10; i += 1) {
      const when = new Date(start.getTime() + i * 1000);
      h.clock.now = when;
      await h.nudgesService.create(
        h.ada,
        h.couple,
        { kind: NudgeKind.HUG },
        when,
      );
    }
    expect(h.nudges).toHaveLength(10);
    expect(h.sender.sent).toHaveLength(10);

    const eleventh = new Date(start.getTime() + 30 * 60 * 1000);
    h.clock.now = eleventh;
    let error: HttpException | undefined;
    try {
      await h.nudgesService.create(
        h.ada,
        h.couple,
        { kind: NudgeKind.KISS },
        eleventh,
      );
    } catch (caught) {
      error = caught as HttpException;
    }
    expect(error).toBeInstanceOf(HttpException);
    expect(error?.getStatus()).toBe(429);
    const body = error?.getResponse() as { retryAfter: number };
    expect(body.retryAfter).toBeGreaterThan(0);
    expect(h.nudges).toHaveLength(10);
    expect(h.sender.sent).toHaveLength(10);
    expect(
      h.events.filter((event) => event.type === ActivityType.NUDGE_SENT),
    ).toHaveLength(10);
  });

  it('always delivers the nudge to the partner, ignoring any client receiver', async () => {
    const h = harness();
    const when = new Date('2026-10-05T15:00:00.000Z');
    h.clock.now = when;
    const created = await h.nudgesService.create(
      h.ada,
      h.couple,
      { kind: NudgeKind.THINKING_OF_YOU },
      when,
    );
    expect(created.receiverId).toBe('bob');
    expect(created.senderId).toBe('ada');
    expect(h.nudges[0].receiverId).toBe('bob');
  });

  it('pushes a nudge and records the feed, unless nudges are off', async () => {
    const h = harness();
    addToken(h, 'bob');
    const when = new Date('2026-10-05T15:00:00.000Z');
    h.clock.now = when;
    await h.nudgesService.create(
      h.ada,
      h.couple,
      { kind: NudgeKind.HUG },
      when,
    );

    expect(h.sender.sent).toHaveLength(1);
    expect(h.sender.sent[0].data).toEqual({
      type: ActivityType.NUDGE_SENT,
      route: '/nudges',
    });
    expect(h.sender.sent[0].collapseKey).toBe('nudge');
    expect(h.sender.sent[0].notification.body).toContain(
      'Ada mandou um abraço',
    );
    expect(
      h.events.some((event) => event.type === ActivityType.NUDGE_SENT),
    ).toBe(true);

    h.prefs.set('bob', {
      userId: 'bob',
      pushEnabled: true,
      lists: true,
      importantDates: true,
      dailyQuestion: true,
      mood: true,
      nudges: false,
      datePlans: true,
      quietStartMin: null,
      quietEndMin: null,
    });
    const later = new Date(when.getTime() + 60_000);
    h.clock.now = later;
    const quiet = await h.nudgesService.create(
      h.ada,
      h.couple,
      { kind: NudgeKind.MISS_YOU, message: 'cadê você' },
      later,
    );
    expect(quiet.receiverId).toBe('bob');
    expect(h.nudges).toHaveLength(2);
    expect(h.sender.sent).toHaveLength(1);
    expect(
      h.events.filter((event) => event.type === ActivityType.NUDGE_SENT),
    ).toHaveLength(2);
  });

  it('collapses the push copy after more than 3 nudges in 10 minutes', async () => {
    const h = harness();
    addToken(h, 'bob');
    const start = new Date('2026-10-05T15:00:00.000Z');
    for (let i = 0; i < 4; i += 1) {
      const when = new Date(start.getTime() + i * 1000);
      h.clock.now = when;
      await h.nudgesService.create(
        h.ada,
        h.couple,
        { kind: NudgeKind.KISS, message: 'segredo' },
        when,
      );
    }
    expect(h.sender.sent[3].notification.body).toBe('Ada mandou 4 carinhos');
    expect(h.sender.sent[3].notification.body).not.toContain('segredo');
    expect(h.sender.sent[3].collapseKey).toBe('nudge');
  });

  it('returns 404 when the sender marks their own nudge as seen', async () => {
    const h = harness();
    const when = new Date('2026-10-05T15:00:00.000Z');
    h.clock.now = when;
    const sent = await h.nudgesService.create(
      h.bob,
      h.couple,
      { kind: NudgeKind.HUG },
      when,
    );
    await expect(
      h.nudgesService.markSeen(h.bob, h.couple, sent.id, when),
    ).rejects.toBeInstanceOf(NotFoundException);

    const seen = await h.nudgesService.markSeen(h.ada, h.couple, sent.id, when);
    expect(seen.seenAt).toEqual(when);
    const received = await h.nudgesService.received(h.ada, h.couple, {});
    expect(received.items).toHaveLength(1);
    expect(received.items[0].id).toBe(sent.id);
    const sendersInbox = await h.nudgesService.received(h.bob, h.couple, {});
    expect(sendersInbox.items).toHaveLength(0);
  });
});

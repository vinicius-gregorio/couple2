/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-argument, @typescript-eslint/require-await */
import { ActivityType, DevicePlatform, ListType } from '@prisma/client';
import { calendarDateToUtc } from '../common/calendar-date';
import { ListsService } from '../lists/lists.service';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { ActivityService } from './activity.service';
import { Clock } from './clock';
import { DevicesService } from './devices.service';
import { FeedService } from './feed.service';
import { LogPushSender } from './log-push.sender';
import { NotificationPreferencesService } from './preferences.service';
import { PushMessage, PushSender, PushSendResult } from './push-sender';
import { UpcomingRemindersService } from './upcoming-reminders.service';

interface UserRow {
  id: string;
  name: string | null;
  partnerId: string | null;
  coupleId: string | null;
  feedSeenAt: Date | null;
  birthDate: Date | null;
}

interface CoupleRow {
  id: string;
  userAId: string;
  userBId: string;
  status: 'ACTIVE' | 'ENDED';
  timezone: string;
  anniversaryDate: Date | null;
}

interface DateRow {
  id: string;
  coupleId: string;
  title: string;
  date: Date;
  recurrence: 'NONE' | 'YEARLY';
}

interface EventRow {
  id: string;
  coupleId: string;
  actorId: string | null;
  type: string;
  entityType: string;
  entityId: string;
  payload: Record<string, unknown> | null;
  createdAt: Date;
}

interface TokenRow {
  id: string;
  userId: string;
  token: string;
  platform: string;
  appVersion?: string;
  locale?: string;
  lastSeenAt: Date;
  createdAt: Date;
}

interface PrefRow {
  userId: string;
  pushEnabled: boolean;
  lists: boolean;
  importantDates: boolean;
  dailyQuestion: boolean;
  mood: boolean;
  nudges: boolean;
  datePlans: boolean;
  quietStartMin: number | null;
  quietEndMin: number | null;
  updatedAt: Date;
}

interface ListRow {
  id: string;
  type: string;
  name: string;
  ownerId: string;
  coupleId: string | null;
  createdAt: Date;
  items?: unknown[];
}

interface ItemRow {
  id: string;
  listId: string;
  content: string;
  metadata: unknown;
  isCompleted: boolean;
  addedById: string;
  createdAt: Date;
}

class RecordingPushSender implements PushSender {
  readonly sent: PushMessage[] = [];
  handler: (message: PushMessage) => PushSendResult[] = (message) =>
    message.tokens.map((token) => ({ token, success: true }));

  async send(message: PushMessage): Promise<PushSendResult[]> {
    this.sent.push(message);
    return this.handler(message);
  }
}

function uniqueError(): Error & { code: string } {
  return Object.assign(new Error('Unique constraint'), { code: 'P2002' });
}

class Memory {
  users = new Map<string, UserRow>();
  couples = new Map<string, CoupleRow>();
  dates: DateRow[] = [];
  events: EventRow[] = [];
  tokens: TokenRow[] = [];
  prefs = new Map<string, PrefRow>();
  lists = new Map<string, ListRow>();
  items = new Map<string, ItemRow>();
  seq = 0;

  constructor(readonly clock: { now: Date }) {}

  next(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${this.seq}`;
  }
}

function project<T extends object>(
  row: T,
  select: Record<string, boolean>,
): Partial<T> {
  const out: Partial<T> = {};
  for (const key of Object.keys(select) as (keyof T)[]) {
    if (select[key as string]) out[key] = row[key];
  }
  return out;
}

function matchEvent(event: EventRow, where: any): boolean {
  if (!where) return true;
  if (where.coupleId && event.coupleId !== where.coupleId) return false;
  if (where.actorId !== undefined && where.actorId !== null) {
    if (event.actorId !== where.actorId) return false;
  }
  if (where.entityId && event.entityId !== where.entityId) return false;
  if (typeof where.type === 'string' && event.type !== where.type) return false;
  if (where.type?.in && !where.type.in.includes(event.type)) return false;
  if (where.createdAt?.gt && !(event.createdAt > where.createdAt.gt))
    return false;
  if (where.OR && !where.OR.some((branch: any) => matchOr(event, branch))) {
    return false;
  }
  return true;
}

function matchOr(event: EventRow, branch: any): boolean {
  if (branch.createdAt?.lt) return event.createdAt < branch.createdAt.lt;
  if (branch.AND) {
    return branch.AND.every((part: any) => {
      if (part.createdAt instanceof Date) {
        return event.createdAt.getTime() === part.createdAt.getTime();
      }
      if (part.id?.lt) return event.id < part.id.lt;
      return true;
    });
  }
  return false;
}

function sortEvents(rows: EventRow[]): EventRow[] {
  return [...rows].sort((a, b) => {
    const byTime = b.createdAt.getTime() - a.createdAt.getTime();
    if (byTime !== 0) return byTime;
    if (a.id === b.id) return 0;
    return a.id < b.id ? 1 : -1;
  });
}

function createPrisma(memory: Memory) {
  return {
    couple: {
      findUnique: async ({ where, select }: any) => {
        const row = memory.couples.get(where.id) ?? null;
        if (!row || !select) return row;
        return project(row, select);
      },
      findMany: async ({ where, include }: any) => {
        let rows = [...memory.couples.values()];
        if (where?.status)
          rows = rows.filter((row) => row.status === where.status);
        if (!include) return rows;
        return rows.map((row) => ({
          ...row,
          dates: memory.dates.filter((date) => date.coupleId === row.id),
          userA: project(memory.users.get(row.userAId)!, include.userA.select),
          userB: project(memory.users.get(row.userBId)!, include.userB.select),
        }));
      },
    },
    user: {
      findUnique: async ({ where, select }: any) => {
        const row = memory.users.get(where.id) ?? null;
        if (!row || !select) return row;
        return project(row, select);
      },
      update: async ({ where, data, select }: any) => {
        const row = memory.users.get(where.id);
        if (!row) throw new Error('user missing');
        Object.assign(row, data);
        return select ? project(row, select) : row;
      },
    },
    activityEvent: {
      create: async ({ data }: any) => {
        const row: EventRow = {
          id: memory.next('evt'),
          coupleId: data.coupleId,
          actorId: data.actorId ?? null,
          type: data.type,
          entityType: data.entityType,
          entityId: data.entityId,
          payload: data.payload ?? null,
          createdAt: new Date(memory.clock.now),
        };
        memory.events.push(row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = memory.events.find((event) => event.id === where.id);
        if (!row) throw new Error('event missing');
        Object.assign(row, data);
        return row;
      },
      findMany: async ({ where, orderBy, take, select }: any) => {
        let rows = memory.events.filter((event) => matchEvent(event, where));
        if (orderBy) rows = sortEvents(rows);
        if (take) rows = rows.slice(0, take);
        if (!select) return rows;
        return rows.map((row) => project(row, select));
      },
      count: async ({ where }: any) =>
        memory.events.filter((event) => matchEvent(event, where)).length,
    },
    deviceToken: {
      upsert: async ({ where, create, update }: any) => {
        const existing = memory.tokens.find(
          (token) => token.token === where.token,
        );
        if (!existing) {
          const row: TokenRow = {
            id: memory.next('tok'),
            createdAt: new Date(memory.clock.now),
            ...create,
          };
          memory.tokens.push(row);
          return row;
        }
        Object.assign(existing, update);
        return existing;
      },
      deleteMany: async ({ where }: any) => {
        const before = memory.tokens.length;
        const removed = memory.tokens.filter((token) =>
          tokenMatches(token, where),
        );
        memory.tokens = memory.tokens.filter(
          (token) => !tokenMatches(token, where),
        );
        return { count: before - memory.tokens.length, removed };
      },
      findMany: async ({ where }: any) =>
        memory.tokens.filter((token) => {
          if (where.userId && token.userId !== where.userId) return false;
          if (
            where.platform?.in &&
            !where.platform.in.includes(token.platform)
          ) {
            return false;
          }
          return true;
        }),
    },
    notificationPreference: {
      findUnique: async ({ where }: any) =>
        memory.prefs.get(where.userId) ?? null,
      findUniqueOrThrow: async ({ where }: any) => {
        const row = memory.prefs.get(where.userId);
        if (!row) throw new Error('prefs missing');
        return row;
      },
      create: async ({ data }: any) => {
        if (memory.prefs.has(data.userId)) throw uniqueError();
        const row: PrefRow = {
          pushEnabled: true,
          lists: true,
          importantDates: true,
          dailyQuestion: true,
          mood: true,
          nudges: true,
          datePlans: true,
          quietStartMin: null,
          quietEndMin: null,
          updatedAt: new Date(memory.clock.now),
          ...data,
        };
        memory.prefs.set(data.userId, row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = memory.prefs.get(where.userId);
        if (!row) throw new Error('prefs missing');
        Object.assign(row, data, { updatedAt: new Date(memory.clock.now) });
        return row;
      },
    },
    partnerList: {
      create: async ({ data, include }: any) => {
        const row: ListRow = {
          id: memory.next('list'),
          createdAt: new Date(memory.clock.now),
          items: include?.items ? [] : undefined,
          ...data,
        };
        memory.lists.set(row.id, row);
        return row;
      },
      findUnique: async ({ where }: any) => memory.lists.get(where.id) ?? null,
    },
    listItem: {
      create: async ({ data }: any) => {
        const row: ItemRow = {
          id: memory.next('item'),
          isCompleted: false,
          createdAt: new Date(memory.clock.now),
          metadata: data.metadata,
          ...data,
        };
        memory.items.set(row.id, row);
        return row;
      },
      findUniqueOrThrow: async ({ where, include }: any) => {
        const row = memory.items.get(where.id);
        if (!row) throw new Error('item missing');
        if (!include?.list) return row;
        return { ...row, list: memory.lists.get(row.listId) };
      },
      update: async ({ where, data }: any) => {
        const row = memory.items.get(where.id);
        if (!row) throw new Error('item missing');
        Object.assign(row, data);
        return row;
      },
    },
  };
}

function tokenMatches(token: TokenRow, where: any): boolean {
  if (where.userId && token.userId !== where.userId) return false;
  if (typeof where.token === 'string' && token.token !== where.token)
    return false;
  if (where.token?.in && !where.token.in.includes(token.token)) return false;
  if (!where.userId && !where.token) return false;
  return true;
}

function harness(initial = new Date('2026-10-05T15:00:00.000Z')) {
  const clock = { now: initial };
  const memory = new Memory(clock);
  const prisma = createPrisma(memory);
  const sender = new RecordingPushSender();
  const time: Clock = { now: () => clock.now };
  const activity = new ActivityService(prisma as never, sender, time);
  const devices = new DevicesService(prisma as never);
  const feed = new FeedService(prisma as never, time);
  const preferences = new NotificationPreferencesService(prisma as never);
  const reminders = new UpcomingRemindersService(prisma as never, activity);
  const lists = new ListsService(prisma as never, activity);
  return {
    clock,
    memory,
    prisma,
    sender,
    activity,
    devices,
    feed,
    preferences,
    reminders,
    lists,
  };
}

function addUser(
  memory: Memory,
  input: {
    id: string;
    name: string;
    partnerId: string | null;
    coupleId: string | null;
    birthDate?: Date | null;
  },
) {
  memory.users.set(input.id, {
    id: input.id,
    name: input.name,
    partnerId: input.partnerId,
    coupleId: input.coupleId,
    feedSeenAt: null,
    birthDate: input.birthDate ?? null,
  });
}

function addCouple(
  memory: Memory,
  input: { id: string; userAId: string; userBId: string; timezone?: string },
) {
  memory.couples.set(input.id, {
    id: input.id,
    userAId: input.userAId,
    userBId: input.userBId,
    status: 'ACTIVE',
    timezone: input.timezone ?? 'America/Sao_Paulo',
    anniversaryDate: null,
  });
}

function viewer(memory: Memory, id: string): UserWithPartner {
  const row = memory.users.get(id)!;
  return {
    ...row,
    email: `${id}@example.com`,
    picture: null,
    googleId: null,
    appleId: null,
    firebaseUid: null,
    pairingCode: null,
    pairingCodeExpiresAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    partner: row.partnerId
      ? {
          id: row.partnerId,
          name: memory.users.get(row.partnerId)?.name ?? null,
          email: `${row.partnerId}@example.com`,
          picture: null,
        }
      : null,
  } as UserWithPartner;
}

describe('push + activity feed', () => {
  it('keeps one row per device and drops only the logging-out device', async () => {
    const { devices, memory } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });

    await devices.register('ada', {
      token: 'phone',
      platform: DevicePlatform.IOS,
    });
    await devices.register('ada', {
      token: 'tablet',
      platform: DevicePlatform.ANDROID,
    });
    expect(memory.tokens).toHaveLength(2);

    await devices.remove('ada', 'phone');
    expect(memory.tokens.map((token) => token.token)).toEqual(['tablet']);
  });

  it('reassigns a token when the same device signs into another account', async () => {
    const { devices, memory } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: null,
      coupleId: null,
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: null,
      coupleId: null,
    });

    await devices.register('ada', {
      token: 'shared',
      platform: DevicePlatform.ANDROID,
    });
    await devices.register('bob', {
      token: 'shared',
      platform: DevicePlatform.ANDROID,
    });

    expect(memory.tokens).toHaveLength(1);
    expect(memory.tokens[0].userId).toBe('bob');

    await devices.remove('ada', 'shared');
    expect(memory.tokens).toHaveLength(1);
    await devices.remove('bob', 'shared');
    expect(memory.tokens).toHaveLength(0);
  });

  it('pushes a completed item to the partner only, on /lists/<id>', async () => {
    const { lists, feed, devices, memory, sender } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    await devices.register('bob', {
      token: 'bob-phone',
      platform: DevicePlatform.ANDROID,
    });

    const list = await lists.createList('ada', 'c1', {
      type: ListType.SHOPPING_CART,
      name: 'Compras',
    });
    const item = await lists.addItem(list.id, 'ada', {
      content: 'leite integral da fazenda',
    });
    sender.sent.length = 0;

    await lists.toggleItem(item.id, 'bob');

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].data).toEqual({
      type: ActivityType.LIST_ITEM_COMPLETED,
      route: `/lists/${list.id}`,
    });
    expect(sender.sent[0].tokens).toEqual(['ada-phone']);
    expect(sender.sent[0].notification.body).toContain('Bob concluiu');

    const adaFeed = await feed.list(viewer(memory, 'ada'), {});
    const bobFeed = await feed.list(viewer(memory, 'bob'), {});
    expect(
      adaFeed.items.some(
        (row) => row.type === ActivityType.LIST_ITEM_COMPLETED,
      ),
    ).toBe(true);
    expect(
      bobFeed.items.some(
        (row) => row.type === ActivityType.LIST_ITEM_COMPLETED,
      ),
    ).toBe(true);

    await lists.toggleItem(item.id, 'bob');
    expect(
      memory.events.filter(
        (event) => event.type === ActivityType.LIST_ITEM_COMPLETED,
      ),
    ).toHaveLength(1);
  });

  it('sends one push when five items land on the same list inside five minutes', async () => {
    const { lists, memory, sender, devices } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });

    const list = await lists.createList('bob', 'c1', {
      type: ListType.MOVIES,
      name: 'Filmes',
    });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    sender.sent.length = 0;

    for (let index = 0; index < 5; index += 1) {
      await lists.addItem(list.id, 'bob', { content: `filme ${index}` });
    }

    const added = memory.events.filter(
      (event) => event.type === ActivityType.LIST_ITEM_ADDED,
    );
    expect(added).toHaveLength(5);
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].data.route).toBe(`/lists/${list.id}`);
    expect(added[0].payload?.content).toBe('filme 0');
  });

  it('deletes a token FCM reports as not registered in the same send', async () => {
    const { lists, devices, memory, sender } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'stale',
      platform: DevicePlatform.ANDROID,
    });
    sender.handler = () => [
      {
        token: 'stale',
        success: false,
        errorCode: 'messaging/registration-token-not-registered',
      },
    ];

    await lists.createList('bob', 'c1', {
      type: ListType.TRAVEL,
      name: 'Viagem',
    });

    expect(sender.sent).toHaveLength(1);
    expect(memory.tokens).toHaveLength(0);
  });

  it('still writes the list and logs the push when the driver is log', async () => {
    const clock = { now: new Date('2026-10-05T15:00:00.000Z') };
    const memory = new Memory(clock);
    const prisma = createPrisma(memory);
    const sender = new LogPushSender();
    const activity = new ActivityService(prisma as never, sender, {
      now: () => clock.now,
    });
    const lists = new ListsService(prisma as never, activity);
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    memory.tokens.push({
      id: 'tok-ada',
      userId: 'ada',
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
      lastSeenAt: clock.now,
      createdAt: clock.now,
    });

    const list = await lists.createList('bob', 'c1', {
      type: ListType.SHOPPING_CART,
      name: 'Compras',
    });

    expect(list.name).toBe('Compras');
    expect(memory.events).toHaveLength(1);
    expect(memory.events[0].payload?.pushedRecipientIds).toEqual(['ada']);
  });

  it('keeps the feed when the lists category is off', async () => {
    const { lists, preferences, devices, memory, sender } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    await preferences.update('ada', { lists: false });

    await lists.createList('bob', 'c1', {
      type: ListType.MOVIES,
      name: 'Filmes',
    });

    expect(memory.events).toHaveLength(1);
    expect(sender.sent).toHaveLength(0);
  });

  it('does not push during quiet hours 23:00–07:00', async () => {
    const { activity, devices, memory, sender } = harness(
      new Date('2026-10-06T02:30:00.000Z'),
    );
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    memory.prefs.set('ada', {
      userId: 'ada',
      pushEnabled: true,
      lists: true,
      importantDates: true,
      dailyQuestion: true,
      mood: true,
      nudges: true,
      datePlans: true,
      quietStartMin: 23 * 60,
      quietEndMin: 7 * 60,
      updatedAt: new Date(),
    });

    await activity.record({
      coupleId: 'c1',
      actorId: 'bob',
      type: ActivityType.LIST_ITEM_ADDED,
      entity: { type: 'ListItem', id: 'item-1' },
      payload: { listId: 'list-1', listName: 'Compras', content: 'pão' },
      push: { route: '/lists/list-1', listId: 'list-1' },
    });

    expect(memory.events).toHaveLength(1);
    expect(sender.sent).toHaveLength(0);
  });

  it('reminds both partners once about a birthday seven days out', async () => {
    const { reminders, devices, memory, sender } = harness(
      new Date('2026-10-05T12:00:00.000Z'),
    );
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
      birthDate: calendarDateToUtc('1990-10-12'),
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    await devices.register('bob', {
      token: 'bob-phone',
      platform: DevicePlatform.ANDROID,
    });

    const first = await reminders.run(new Date('2026-10-05T12:00:00.000Z'));
    expect(first.recorded).toBe(1);
    expect(memory.events).toHaveLength(1);
    expect(memory.events[0].type).toBe(ActivityType.COUPLE_DATE_UPCOMING);
    expect(memory.events[0].actorId).toBeNull();
    expect(memory.events[0].payload).toEqual(
      expect.objectContaining({
        occurrenceDate: '2026-10-12',
        inDays: 7,
        title: 'Aniversário de Bob',
      }),
    );
    expect(sender.sent).toHaveLength(2);
    expect(sender.sent.map((message) => message.tokens[0]).sort()).toEqual([
      'ada-phone',
      'bob-phone',
    ]);
    expect(
      sender.sent.every((message) => message.data.route === '/couple/dates'),
    ).toBe(true);

    const again = await reminders.run(new Date('2026-10-05T12:00:00.000Z'));
    expect(again.recorded).toBe(0);
    expect(memory.events).toHaveLength(1);
    expect(sender.sent).toHaveLength(2);

    sender.sent.length = 0;
    const tooEarly = await reminders.run(new Date('2026-10-05T11:00:00.000Z'));
    expect(tooEarly.recorded).toBe(0);
    expect(sender.sent).toHaveLength(0);
  });

  it('hides another couple and does not repeat cursor pages', async () => {
    const { feed, memory } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'cia',
      name: 'Cia',
      partnerId: 'dan',
      coupleId: 'c2',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    addCouple(memory, { id: 'c2', userAId: 'cia', userBId: 'dan' });

    for (let index = 0; index < 5; index += 1) {
      memory.events.push({
        id: `evt-${index}`,
        coupleId: 'c1',
        actorId: index % 2 === 0 ? 'bob' : 'ada',
        type: ActivityType.LIST_ITEM_ADDED,
        entityType: 'ListItem',
        entityId: `item-${index}`,
        payload: { listId: 'list-1', content: `n${index}` },
        createdAt: new Date(Date.UTC(2026, 9, 5, 12, index, 0)),
      });
    }
    memory.events.push({
      id: 'secret',
      coupleId: 'c2',
      actorId: 'cia',
      type: ActivityType.LIST_CREATED,
      entityType: 'PartnerList',
      entityId: 'other',
      payload: { listName: 'Segredo' },
      createdAt: new Date('2026-10-05T18:00:00.000Z'),
    });

    const foreign = await feed.list(viewer(memory, 'cia'), {});
    expect(foreign.items.map((item) => item.id)).toEqual(['secret']);

    const seen = new Set<string>();
    let cursor: string | undefined;
    const pages: string[][] = [];
    for (let page = 0; page < 4; page += 1) {
      const result = await feed.list(viewer(memory, 'ada'), {
        cursor,
        limit: 2,
      });
      const ids = result.items.map((item) => item.id);
      pages.push(ids);
      for (const id of ids) {
        expect(seen.has(id)).toBe(false);
        seen.add(id);
      }
      if (!result.nextCursor) break;
      cursor = result.nextCursor;
    }

    expect(seen).toEqual(
      new Set(['evt-4', 'evt-3', 'evt-2', 'evt-1', 'evt-0']),
    );
    expect(pages[0]).toEqual(['evt-4', 'evt-3']);
    expect(pages[1]).toEqual(['evt-2', 'evt-1']);
    expect(pages[2]).toEqual(['evt-0']);
  });

  it('counts only newer partner events as unread', async () => {
    const { feed, memory, clock } = harness(
      new Date('2026-10-05T18:00:00.000Z'),
    );
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    memory.events.push(
      {
        id: 'from-bob',
        coupleId: 'c1',
        actorId: 'bob',
        type: ActivityType.LIST_ITEM_ADDED,
        entityType: 'ListItem',
        entityId: 'i1',
        payload: {},
        createdAt: new Date('2026-10-05T12:00:00.000Z'),
      },
      {
        id: 'from-ada',
        coupleId: 'c1',
        actorId: 'ada',
        type: ActivityType.LIST_ITEM_ADDED,
        entityType: 'ListItem',
        entityId: 'i2',
        payload: {},
        createdAt: new Date('2026-10-05T13:00:00.000Z'),
      },
      {
        id: 'system',
        coupleId: 'c1',
        actorId: null,
        type: ActivityType.COUPLE_DATE_UPCOMING,
        entityType: 'User',
        entityId: 'bob',
        payload: {},
        createdAt: new Date('2026-10-05T14:00:00.000Z'),
      },
    );

    expect((await feed.unreadCount(viewer(memory, 'ada'))).count).toBe(1);
    await feed.markSeen('ada');
    expect(memory.users.get('ada')?.feedSeenAt?.toISOString()).toBe(
      clock.now.toISOString(),
    );
    expect((await feed.unreadCount(viewer(memory, 'ada'))).count).toBe(0);
  });

  it('never records gift or private lists', async () => {
    const { lists, memory, sender, devices } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });

    await lists.createList('bob', 'c1', {
      type: 'GIFT_IDEAS' as ListType,
      name: 'Presentes',
    });

    expect(memory.events).toHaveLength(0);
    expect(sender.sent).toHaveLength(0);
  });

  it('swallows a push failure so the list request still returns', async () => {
    const { lists, memory, sender, devices } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'ada-phone',
      platform: DevicePlatform.IOS,
    });
    sender.handler = () => {
      throw new Error('fcm down');
    };

    const list = await lists.createList('bob', 'c1', {
      type: ListType.MILESTONES,
      name: 'Marcos',
    });

    expect(list.id).toBeTruthy();
    expect(memory.events).toHaveLength(1);
  });

  it('ignores web tokens because web push is out of scope', async () => {
    const { lists, devices, memory, sender } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    await devices.register('ada', {
      token: 'browser',
      platform: DevicePlatform.WEB,
    });

    await lists.createList('bob', 'c1', {
      type: ListType.MOVIES,
      name: 'Filmes',
    });

    expect(memory.tokens).toHaveLength(1);
    expect(sender.sent).toHaveLength(0);
    expect(memory.events).toHaveLength(1);
  });

  it('truncates item content in the stored snapshot', async () => {
    const { lists, memory } = harness();
    addUser(memory, {
      id: 'ada',
      name: 'Ada',
      partnerId: 'bob',
      coupleId: 'c1',
    });
    addUser(memory, {
      id: 'bob',
      name: 'Bob',
      partnerId: 'ada',
      coupleId: 'c1',
    });
    addCouple(memory, { id: 'c1', userAId: 'ada', userBId: 'bob' });
    const list = await lists.createList('bob', 'c1', {
      type: ListType.SHOPPING_CART,
      name: 'Compras',
    });
    const content = 'x'.repeat(120);
    await lists.addItem(list.id, 'bob', { content });
    const added = memory.events.find(
      (event) => event.type === ActivityType.LIST_ITEM_ADDED,
    );
    expect(String(added?.payload?.content).length).toBeLessThanOrEqual(80);
    expect(String(added?.payload?.content).endsWith('…')).toBe(true);
  });
});

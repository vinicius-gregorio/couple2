/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call */
import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { UpcomingRemindersService } from '../src/notifications/upcoming-reminders.service';
import {
  PUSH_SENDER,
  PushMessage,
  PushSender,
} from '../src/notifications/push-sender';
import { PrismaService } from '../src/prisma';

type AuthBody = {
  accessToken: string;
  user: { id: string; pairingCode: string };
};

const LOCAL_NINE = new Date('2026-10-05T12:00:00.000Z');
const GIFT_A = 'Pulseira de ouro';
const GIFT_B = 'Livro de poesia';
const SECRET_LIST = 'Presentes escondidos';

describe('Gift ideas (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;
  let reminders: UpcomingRemindersService;
  const sent: PushMessage[] = [];
  const prefix = `e2e-gifts-${Date.now()}`;
  const userIds: string[] = [];

  const sender: PushSender = {
    send(message: PushMessage) {
      sent.push(message);
      return Promise.resolve(
        message.tokens.map((token) => ({ token, success: true })),
      );
    },
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PUSH_SENDER)
      .useValue(sender)
      .compile();

    app = moduleFixture.createNestApplication();
    configureApp(app);
    await app.init();
    prisma = app.get(PrismaService);
    reminders = app.get(UpcomingRemindersService);
  });

  afterAll(async () => {
    await cleanup(prisma, userIds);
    await app.close();
  });

  beforeEach(() => {
    sent.length = 0;
  });

  it('creates GIFT_IDEAS without visibility as PRIVATE_FROM_PARTNER', async () => {
    const ada = await paired(app, prisma, prefix, 'ac1', userIds);
    const created = await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({ type: 'GIFT_IDEAS', name: 'Para Bia' })
      .expect(201);

    expect(created.body.visibility).toBe('PRIVATE_FROM_PARTNER');
    expect(created.body.ownerId).toBe(ada.a.user.id);
    expect(created.body.coupleId).toBe(ada.coupleId);

    const stored = await prisma.partnerList.findUniqueOrThrow({
      where: { id: created.body.id },
    });
    expect(stored.visibility).toBe('PRIVATE_FROM_PARTNER');
  });

  it('hides a private list from the partner list, including id, name, and counts', async () => {
    const ada = await paired(app, prisma, prefix, 'ac2', userIds);
    const secret = await createPrivate(app, ada.a, SECRET_LIST);
    await addItem(app, ada.a, secret.id, GIFT_A);

    await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .send({ type: 'MOVIES', name: 'Filmes juntos' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .get('/lists')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .expect(200);

    const body = JSON.stringify(response.body);
    expect(body).not.toContain(secret.id);
    expect(body).not.toContain(SECRET_LIST);
    expect(body).not.toContain(GIFT_A);
    expect(response.body).toHaveLength(1);
    expect(response.body[0].name).toBe('Filmes juntos');
    expect(
      response.body.every(
        (list: { items?: unknown[] }) =>
          !Array.isArray(list.items) ||
          list.items.every(
            (item) => JSON.stringify(item).indexOf(GIFT_A) === -1,
          ),
      ),
    ).toBe(true);
  });

  it('returns 404 on every private list read and write the partner can call', async () => {
    const ada = await paired(app, prisma, prefix, 'ac3', userIds);
    const secret = await createPrivate(app, ada.a, SECRET_LIST);
    const item = await addItem(app, ada.a, secret.id, GIFT_A);

    const partner = ada.b.accessToken;
    const routes: Array<{
      method: 'get' | 'post' | 'patch' | 'delete';
      url: string;
      body?: Record<string, unknown>;
    }> = [
      { method: 'get', url: `/lists/${secret.id}` },
      {
        method: 'post',
        url: `/lists/${secret.id}/items`,
        body: { content: 'vazou' },
      },
      { method: 'patch', url: `/lists/items/${item.id}` },
      { method: 'delete', url: `/lists/items/${item.id}` },
      { method: 'delete', url: `/lists/${secret.id}` },
    ];

    for (const route of routes) {
      const call = request(app.getHttpServer())
        [route.method](route.url)
        .set('Authorization', `Bearer ${partner}`);
      const response = route.body ? await call.send(route.body) : await call;
      expect(response.status).toBe(404);
      const text = JSON.stringify(response.body);
      expect(text).not.toContain(SECRET_LIST);
      expect(text).not.toContain(GIFT_A);
      expect(text).not.toContain('Forbidden');
    }

    const stored = await prisma.listItem.findUniqueOrThrow({
      where: { id: item.id },
    });
    expect(stored.content).toBe(GIFT_A);
    expect(stored.isCompleted).toBe(false);
    expect(
      await prisma.partnerList.findUnique({ where: { id: secret.id } }),
    ).not.toBeNull();
  });

  it('walks every /lists route as the partner and leaks nothing about the private list', async () => {
    const ada = await paired(app, prisma, prefix, 'ac10', userIds);
    const secret = await createPrivate(app, ada.a, SECRET_LIST);
    const item = await addItem(app, ada.a, secret.id, GIFT_A);
    const auth = { Authorization: `Bearer ${ada.b.accessToken}` };

    const listed = await request(app.getHttpServer())
      .get('/lists')
      .set(auth)
      .expect(200);
    expect(JSON.stringify(listed.body)).not.toContain(secret.id);
    expect(JSON.stringify(listed.body)).not.toContain(SECRET_LIST);
    expect(JSON.stringify(listed.body)).not.toContain(GIFT_A);

    const created = await request(app.getHttpServer())
      .post('/lists')
      .set(auth)
      .send({ type: 'TRAVEL', name: 'Viagem' })
      .expect(201);
    expect(JSON.stringify(created.body)).not.toContain(secret.id);
    expect(JSON.stringify(created.body)).not.toContain(GIFT_A);

    await request(app.getHttpServer())
      .get(`/lists/${secret.id}`)
      .set(auth)
      .expect(404);
    await request(app.getHttpServer())
      .post(`/lists/${secret.id}/items`)
      .set(auth)
      .send({ content: 'nao' })
      .expect(404);
    await request(app.getHttpServer())
      .patch(`/lists/items/${item.id}`)
      .set(auth)
      .expect(404);
    await request(app.getHttpServer())
      .delete(`/lists/items/${item.id}`)
      .set(auth)
      .expect(404);
    await request(app.getHttpServer())
      .delete(`/lists/${secret.id}`)
      .set(auth)
      .expect(404);

    const own = await request(app.getHttpServer())
      .get(`/lists/${created.body.id}`)
      .set(auth)
      .expect(200);
    expect(own.body.id).toBe(created.body.id);
    expect(JSON.stringify(own.body)).not.toContain(GIFT_A);

    expect(
      await prisma.partnerList.findUnique({ where: { id: secret.id } }),
    ).not.toBeNull();
    expect(
      (await prisma.listItem.findUniqueOrThrow({ where: { id: item.id } }))
        .content,
    ).toBe(GIFT_A);
  });

  it('records no activity and no partner push for a private gift list', async () => {
    const ada = await paired(app, prisma, prefix, 'ac4', userIds);
    await registerDevice(app, ada.b, `${prefix}-ac4-b`);
    const secret = await createPrivate(app, ada.a, SECRET_LIST);
    const item = await addItem(app, ada.a, secret.id, GIFT_A);
    await request(app.getHttpServer())
      .patch(`/lists/items/${item.id}`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .expect(200);

    expect(
      await prisma.activityEvent.count({ where: { coupleId: ada.coupleId } }),
    ).toBe(0);
    expect(
      sent.filter((message) => message.tokens.includes(`${prefix}-ac4-b`)),
    ).toHaveLength(0);

    const feed = await request(app.getHttpServer())
      .get('/feed')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .expect(200);
    expect(JSON.stringify(feed.body)).not.toContain(GIFT_A);
    expect(JSON.stringify(feed.body)).not.toContain(SECRET_LIST);
  });

  it('rejects PRIVATE_FROM_PARTNER on a non-gift list', async () => {
    const ada = await paired(app, prisma, prefix, 'ac5', userIds);
    await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({
        type: 'MOVIES',
        name: 'Segredo',
        visibility: 'PRIVATE_FROM_PARTNER',
      })
      .expect(400);

    expect(
      await prisma.partnerList.count({
        where: { coupleId: ada.coupleId, name: 'Segredo' },
      }),
    ).toBe(0);
  });

  it('shares a GIFT_IDEAS wishlist and writes the feed event', async () => {
    const ada = await paired(app, prisma, prefix, 'ac6', userIds);
    await registerDevice(app, ada.a, `${prefix}-ac6-a`);
    const created = await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .send({
        type: 'GIFT_IDEAS',
        name: 'Minha wishlist',
        visibility: 'SHARED',
      })
      .expect(201);
    expect(created.body.visibility).toBe('SHARED');

    const lists = await request(app.getHttpServer())
      .get('/lists')
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .expect(200);
    expect(lists.body.map((list: { id: string }) => list.id)).toContain(
      created.body.id,
    );

    await request(app.getHttpServer())
      .post(`/lists/${created.body.id}/items`)
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .send({ content: 'Caneca' })
      .expect(201);

    const events = await prisma.activityEvent.findMany({
      where: { coupleId: ada.coupleId },
    });
    expect(events.map((event) => event.type).sort()).toEqual([
      'LIST_CREATED',
      'LIST_ITEM_ADDED',
    ]);
    expect(
      sent.some((message) => message.tokens.includes(`${prefix}-ac6-a`)),
    ).toBe(true);

    const feed = await request(app.getHttpServer())
      .get('/feed')
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .expect(200);
    expect(JSON.stringify(feed.body)).toContain('Minha wishlist');
  });

  it('rejects a javascript url and a negative price', async () => {
    const ada = await paired(app, prisma, prefix, 'ac7', userIds);
    const secret = await createPrivate(app, ada.a, SECRET_LIST);

    await request(app.getHttpServer())
      .post(`/lists/${secret.id}/items`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({ content: 'Ruim', metadata: { url: 'javascript:alert(1)' } })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/lists/${secret.id}/items`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({ content: 'Ruim', metadata: { price: -1 } })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/lists/${secret.id}/items`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({ content: 'Ruim', metadata: { status: 'DELIVERED' } })
      .expect(400);

    const ok = await request(app.getHttpServer())
      .post(`/lists/${secret.id}/items`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .send({
        content: 'Ok',
        metadata: {
          price: 0,
          currency: 'BRL',
          url: 'https://example.com/gift',
          occasion: 'BIRTHDAY',
          status: 'IDEA',
        },
      })
      .expect(201);
    expect(ok.body.metadata).toEqual({
      price: 0,
      currency: 'BRL',
      url: 'https://example.com/gift',
      occasion: 'BIRTHDAY',
      status: 'IDEA',
    });

    expect(await prisma.listItem.count({ where: { listId: secret.id } })).toBe(
      1,
    );
  });

  it('pushes one D-14 gift reminder to the owner and none when there are no ideas', async () => {
    const ada = await paired(app, prisma, prefix, 'ac8', userIds);
    await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .send({ birthDate: '1992-10-19' })
      .expect(200);

    const adaToken = `${prefix}-ac8-a`;
    const biaToken = `${prefix}-ac8-b`;
    await registerDevice(app, ada.a, adaToken);
    await registerDevice(app, ada.b, biaToken);

    const secret = await createPrivate(app, ada.a, SECRET_LIST);
    await addItem(app, ada.a, secret.id, GIFT_A, { status: 'IDEA' });
    await addItem(app, ada.a, secret.id, GIFT_B, { status: 'BOUGHT' });
    const delivered = await addItem(app, ada.a, secret.id, 'Já entregue');
    await request(app.getHttpServer())
      .patch(`/lists/items/${delivered.id}`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .expect(200);

    sent.length = 0;
    await reminders.run(LOCAL_NINE);

    const giftPushes = sent.filter(
      (message) =>
        message.data.type === 'GIFT_REMINDER' &&
        (message.tokens.includes(adaToken) ||
          message.tokens.includes(biaToken)),
    );
    expect(giftPushes).toHaveLength(1);
    expect(giftPushes[0].tokens).toEqual([adaToken]);
    expect(giftPushes[0].notification.body).toContain('Bia');
    expect(giftPushes[0].notification.body).toContain('14 dias');
    expect(giftPushes[0].notification.body).toContain('2 ideias');
    expect(giftPushes[0].notification.body).not.toContain(GIFT_A);
    expect(giftPushes[0].notification.body).not.toContain(GIFT_B);
    expect(giftPushes[0].notification.body).not.toContain(SECRET_LIST);
    expect(giftPushes[0].notification.title).not.toContain(GIFT_A);
    expect(sent.some((message) => message.tokens.includes(biaToken))).toBe(
      false,
    );

    expect(
      await prisma.activityEvent.count({ where: { coupleId: ada.coupleId } }),
    ).toBe(0);
    const feed = await request(app.getHttpServer())
      .get('/feed')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .expect(200);
    expect(JSON.stringify(feed.body)).not.toContain(GIFT_A);

    const again = await reminders.run(LOCAL_NINE);
    expect(again.giftReminders).toBe(0);
    expect(
      sent.filter((message) => message.data.type === 'GIFT_REMINDER'),
    ).toHaveLength(1);

    const quiet = await paired(app, prisma, prefix, 'ac8-none', userIds);
    await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${quiet.b.accessToken}`)
      .send({ birthDate: '1992-10-19' })
      .expect(200);
    const quietToken = `${prefix}-ac8-none`;
    await registerDevice(app, quiet.a, quietToken);
    const empty = await createPrivate(app, quiet.a, 'Sem ideias');
    const done = await addItem(app, quiet.a, empty.id, 'Entregue');
    await request(app.getHttpServer())
      .patch(`/lists/items/${done.id}`)
      .set('Authorization', `Bearer ${quiet.a.accessToken}`)
      .expect(200);

    sent.length = 0;
    await reminders.run(LOCAL_NINE);
    expect(
      sent.filter(
        (message) =>
          message.data.type === 'GIFT_REMINDER' &&
          message.tokens.includes(quietToken),
      ),
    ).toHaveLength(0);
  });

  it('skips the gift reminder when importantDates is off and covers the anniversary', async () => {
    const muted = await paired(app, prisma, prefix, 'ac8-pref', userIds);
    await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${muted.b.accessToken}`)
      .send({ birthDate: '1992-10-19' })
      .expect(200);
    await request(app.getHttpServer())
      .patch('/notifications/preferences')
      .set('Authorization', `Bearer ${muted.a.accessToken}`)
      .send({ importantDates: false })
      .expect(200);
    const mutedToken = `${prefix}-ac8-pref`;
    await registerDevice(app, muted.a, mutedToken);
    const list = await createPrivate(app, muted.a, SECRET_LIST);
    await addItem(app, muted.a, list.id, GIFT_A);

    sent.length = 0;
    await reminders.run(LOCAL_NINE);
    expect(
      sent.filter((message) => message.tokens.includes(mutedToken)),
    ).toHaveLength(0);

    const anniversary = await paired(app, prisma, prefix, 'ac8-ann', userIds);
    await request(app.getHttpServer())
      .patch('/couple')
      .set('Authorization', `Bearer ${anniversary.a.accessToken}`)
      .send({ anniversaryDate: '2020-10-19' })
      .expect(200);
    const ownerToken = `${prefix}-ac8-ann-a`;
    const partnerToken = `${prefix}-ac8-ann-b`;
    await registerDevice(app, anniversary.a, ownerToken);
    await registerDevice(app, anniversary.b, partnerToken);
    const ideas = await createPrivate(app, anniversary.a, SECRET_LIST);
    await addItem(app, anniversary.a, ideas.id, GIFT_A);

    sent.length = 0;
    await reminders.run(LOCAL_NINE);
    const pushes = sent.filter(
      (message) => message.data.type === 'GIFT_REMINDER',
    );
    expect(pushes).toHaveLength(1);
    expect(pushes[0].tokens).toEqual([ownerToken]);
    expect(pushes[0].notification.body).toContain('Aniversário de namoro');
    expect(pushes[0].notification.body).not.toContain(GIFT_A);
    expect(sent.some((message) => message.tokens.includes(partnerToken))).toBe(
      false,
    );
    expect(
      await prisma.activityEvent.count({
        where: { coupleId: anniversary.coupleId },
      }),
    ).toBe(0);

    await reminders.run(LOCAL_NINE);
    expect(
      sent.filter((message) => message.data.type === 'GIFT_REMINDER'),
    ).toHaveLength(1);
  });

  it('keeps existing list types shared after the visibility default', async () => {
    const ada = await paired(app, prisma, prefix, 'ac9', userIds);
    const defaults = await prisma.$queryRaw<Array<{ column_default: string }>>`
      SELECT column_default
      FROM information_schema.columns
      WHERE table_name = 'partner_lists' AND column_name = 'visibility'
    `;
    expect(defaults[0].column_default).toContain('SHARED');

    const orphan = await prisma.partnerList.create({
      data: {
        type: 'SHOPPING_CART',
        name: 'Antes da coluna',
        ownerId: ada.a.user.id,
        coupleId: ada.coupleId,
      },
    });
    expect(orphan.visibility).toBe('SHARED');

    for (const type of ['SHOPPING_CART', 'MOVIES', 'MILESTONES', 'TRAVEL']) {
      const created = await request(app.getHttpServer())
        .post('/lists')
        .set('Authorization', `Bearer ${ada.a.accessToken}`)
        .send({ type, name: type })
        .expect(201);
      expect(created.body.visibility).toBe('SHARED');
    }

    const visible = await request(app.getHttpServer())
      .get('/lists')
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .expect(200);
    expect(
      visible.body.map((list: { name: string }) => list.name).sort(),
    ).toEqual(
      [
        'Antes da coluna',
        'MILESTONES',
        'MOVIES',
        'SHOPPING_CART',
        'TRAVEL',
      ].sort(),
    );

    const movies = visible.body.find(
      (list: { type: string }) => list.type === 'MOVIES',
    );
    const item = await request(app.getHttpServer())
      .post(`/lists/${movies.id}/items`)
      .set('Authorization', `Bearer ${ada.b.accessToken}`)
      .send({ content: 'Before Sunrise', metadata: { platform: 'TV' } })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/lists/items/${item.body.id}`)
      .set('Authorization', `Bearer ${ada.a.accessToken}`)
      .expect(200);

    const events = await prisma.activityEvent.findMany({
      where: { coupleId: ada.coupleId },
    });
    expect(events.map((event) => event.type)).toEqual(
      expect.arrayContaining([
        'LIST_CREATED',
        'LIST_ITEM_ADDED',
        'LIST_ITEM_COMPLETED',
      ]),
    );
  });
});

async function paired(
  app: INestApplication<App>,
  prisma: PrismaService,
  prefix: string,
  label: string,
  userIds: string[],
) {
  const a = await login(app, `${prefix}-${label}-a@example.com`, 'Ada');
  const b = await login(app, `${prefix}-${label}-b@example.com`, 'Bia');
  userIds.push(a.user.id, b.user.id);
  await pair(app, a, b);
  const row = await prisma.user.findUniqueOrThrow({ where: { id: a.user.id } });
  return { a, b, coupleId: row.coupleId as string };
}

async function createPrivate(
  app: INestApplication<App>,
  user: AuthBody,
  name: string,
) {
  const response = await request(app.getHttpServer())
    .post('/lists')
    .set('Authorization', `Bearer ${user.accessToken}`)
    .send({ type: 'GIFT_IDEAS', name })
    .expect(201);
  return response.body as { id: string; visibility: string };
}

async function addItem(
  app: INestApplication<App>,
  user: AuthBody,
  listId: string,
  content: string,
  metadata?: Record<string, unknown>,
) {
  const response = await request(app.getHttpServer())
    .post(`/lists/${listId}/items`)
    .set('Authorization', `Bearer ${user.accessToken}`)
    .send({ content, ...(metadata ? { metadata } : {}) })
    .expect(201);
  return response.body as { id: string };
}

async function registerDevice(
  app: INestApplication<App>,
  user: AuthBody,
  token: string,
) {
  await request(app.getHttpServer())
    .post('/devices')
    .set('Authorization', `Bearer ${user.accessToken}`)
    .send({ token, platform: 'IOS' })
    .expect(200);
}

function login(app: INestApplication<App>, email: string, name: string) {
  return request(app.getHttpServer())
    .post('/auth/dev-login')
    .send({ email, name })
    .expect(201)
    .then((response) => response.body as AuthBody);
}

async function pair(
  app: INestApplication<App>,
  first: AuthBody,
  second: AuthBody,
) {
  await request(app.getHttpServer())
    .post('/pairing/pair')
    .set('Authorization', `Bearer ${first.accessToken}`)
    .send({ code: second.user.pairingCode })
    .expect(201);
  await request(app.getHttpServer())
    .post('/pairing/pair')
    .set('Authorization', `Bearer ${second.accessToken}`)
    .send({ code: first.user.pairingCode })
    .expect(201);
}

async function cleanup(prisma: PrismaService, userIds: string[]) {
  if (userIds.length === 0) return;
  await prisma.giftReminderDispatch.deleteMany({
    where: { userId: { in: userIds } },
  });
  await prisma.listItem.deleteMany({
    where: { list: { ownerId: { in: userIds } } },
  });
  await prisma.partnerList.deleteMany({ where: { ownerId: { in: userIds } } });
  await prisma.deviceToken.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.user.updateMany({
    where: { id: { in: userIds } },
    data: { partnerId: null, coupleId: null },
  });
  await prisma.couple.deleteMany({
    where: { OR: [{ userAId: { in: userIds } }, { userBId: { in: userIds } }] },
  });
  await prisma.pairingRequest.deleteMany({
    where: { requesterId: { in: userIds } },
  });
  await prisma.user.deleteMany({ where: { id: { in: userIds } } });
}

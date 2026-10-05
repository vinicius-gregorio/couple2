import { readFileSync } from 'fs';
import { join } from 'path';
import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/configure-app';
import { daysTogether } from '../src/couple/couple-calendar';
import { applyPairing } from '../src/pairing/apply-pairing';
import { PrismaService } from '../src/prisma';

type AuthBody = {
  accessToken: string;
  user: { id: string; pairingCode: string };
};

describe('Couple record (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;
  const prefix = `e2e-couple-${Date.now()}`;
  const userIds: string[] = [];

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    configureApp(app);
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await cleanup(prisma, userIds);
    await app.close();
  });

  it('writes partnerId and coupleId together, and rolls both back if the transaction fails', async () => {
    const alpha = await login(
      app,
      `${prefix}-rollback-a@example.com`,
      'Rollback A',
    );
    const beta = await login(
      app,
      `${prefix}-rollback-b@example.com`,
      'Rollback B',
    );
    userIds.push(alpha.user.id, beta.user.id);

    await expect(
      prisma.$transaction(async (tx) => {
        await applyPairing(tx, alpha.user.id, beta.user.id);
        throw new Error('boom');
      }),
    ).rejects.toThrow('boom');

    const fresh = await prisma.user.findUniqueOrThrow({
      where: { id: alpha.user.id },
    });
    expect(fresh.partnerId).toBeNull();
    expect(fresh.coupleId).toBeNull();
    expect(
      await prisma.couple.count({
        where: {
          OR: [{ userAId: alpha.user.id }, { userBId: alpha.user.id }],
        },
      }),
    ).toBe(0);
  });

  it('creates one active couple on pairing and ends it on unpair', async () => {
    const ada = await login(app, `${prefix}-ada@example.com`, 'Ada');
    const bob = await login(app, `${prefix}-bob@example.com`, 'Bob');
    userIds.push(ada.user.id, bob.user.id);

    await prisma.partnerList.create({
      data: {
        type: 'MOVIES',
        name: 'Before pairing',
        ownerId: ada.user.id,
      },
    });

    await request(app.getHttpServer())
      .post('/pairing/pair')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ code: bob.user.pairingCode })
      .expect(201);

    await request(app.getHttpServer())
      .post('/pairing/pair')
      .set('Authorization', `Bearer ${bob.accessToken}`)
      .send({ code: ada.user.pairingCode })
      .expect(201);

    const adaRow = await prisma.user.findUniqueOrThrow({
      where: { id: ada.user.id },
    });
    const bobRow = await prisma.user.findUniqueOrThrow({
      where: { id: bob.user.id },
    });
    expect(adaRow.partnerId).toBe(bob.user.id);
    expect(bobRow.partnerId).toBe(ada.user.id);
    expect(adaRow.coupleId).toBeTruthy();
    expect(adaRow.coupleId).toBe(bobRow.coupleId);

    const active = await prisma.couple.findMany({
      where: {
        status: 'ACTIVE',
        OR: [{ userAId: ada.user.id }, { userBId: ada.user.id }],
      },
    });
    expect(active).toHaveLength(1);
    expect([active[0].userAId, active[0].userBId].sort()).toEqual(
      [ada.user.id, bob.user.id].sort(),
    );

    const attached = await prisma.partnerList.findFirstOrThrow({
      where: { ownerId: ada.user.id, name: 'Before pairing' },
    });
    expect(attached.coupleId).toBe(adaRow.coupleId);

    const me = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(200);
    const meBody = readBody<{
      user: { coupleId: string | null; birthDate: string | null };
    }>(me);
    expect(meBody.user.coupleId).toBe(adaRow.coupleId);
    expect(meBody.user.birthDate).toBeNull();

    await request(app.getHttpServer())
      .delete('/pairing/unpair')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(200);

    const ended = await prisma.couple.findUniqueOrThrow({
      where: { id: adaRow.coupleId! },
    });
    expect(ended.status).toBe('ENDED');
    expect(ended.endedAt).not.toBeNull();

    const adaAfter = await prisma.user.findUniqueOrThrow({
      where: { id: ada.user.id },
    });
    const bobAfter = await prisma.user.findUniqueOrThrow({
      where: { id: bob.user.id },
    });
    expect(adaAfter.coupleId).toBeNull();
    expect(bobAfter.coupleId).toBeNull();
    expect(adaAfter.partnerId).toBeNull();
    expect(bobAfter.partnerId).toBeNull();

    await request(app.getHttpServer())
      .get('/couple')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(403);
    await request(app.getHttpServer())
      .get('/couple')
      .set('Authorization', `Bearer ${bob.accessToken}`)
      .expect(403);
  });

  it('does not leak lists from an ended couple into the next pairing', async () => {
    const ada = await login(app, `${prefix}-leak-a@example.com`, 'Ada');
    const bob = await login(app, `${prefix}-leak-b@example.com`, 'Bob');
    const cia = await login(app, `${prefix}-leak-c@example.com`, 'Cia');
    userIds.push(ada.user.id, bob.user.id, cia.user.id);

    await pair(app, ada, bob);

    const created = await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ type: 'SHOPPING_CART', name: 'Secret list' })
      .expect(201);
    const listId = readBody<{ id: string }>(created).id;

    const item = await request(app.getHttpServer())
      .post(`/lists/${listId}/items`)
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ content: 'roses' })
      .expect(201);

    await request(app.getHttpServer())
      .delete('/pairing/unpair')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(200);

    const adaAgain = await login(app, `${prefix}-leak-a@example.com`, 'Ada');
    const ciaAgain = await login(app, `${prefix}-leak-c@example.com`, 'Cia');
    await pair(app, adaAgain, ciaAgain);

    const ciasLists = await request(app.getHttpServer())
      .get('/lists')
      .set('Authorization', `Bearer ${ciaAgain.accessToken}`)
      .expect(200);
    expect(
      readBody<Array<{ id: string }>>(ciasLists).map((list) => list.id),
    ).not.toContain(listId);

    const adasLists = await request(app.getHttpServer())
      .get('/lists')
      .set('Authorization', `Bearer ${adaAgain.accessToken}`)
      .expect(200);
    expect(
      readBody<Array<{ id: string }>>(adasLists).map((list) => list.id),
    ).not.toContain(listId);

    await request(app.getHttpServer())
      .get(`/lists/${listId}`)
      .set('Authorization', `Bearer ${ciaAgain.accessToken}`)
      .expect(404);

    await request(app.getHttpServer())
      .post(`/lists/${listId}/items`)
      .set('Authorization', `Bearer ${ciaAgain.accessToken}`)
      .send({ content: 'nope' })
      .expect(404);

    const stored = await prisma.listItem.findUniqueOrThrow({
      where: { id: readBody<{ id: string }>(item).id },
    });
    expect(stored.content).toBe('roses');
  });

  it('returns 404 when another couple patches or deletes a list item', async () => {
    const ada = await login(app, `${prefix}-idor-a@example.com`, 'Ada');
    const bob = await login(app, `${prefix}-idor-b@example.com`, 'Bob');
    const dee = await login(app, `${prefix}-idor-d@example.com`, 'Dee');
    const eve = await login(app, `${prefix}-idor-e@example.com`, 'Eve');
    userIds.push(ada.user.id, bob.user.id, dee.user.id, eve.user.id);

    await pair(app, ada, bob);
    await pair(app, dee, eve);

    const created = await request(app.getHttpServer())
      .post('/lists')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ type: 'MOVIES', name: 'Watch' })
      .expect(201);
    const item = await request(app.getHttpServer())
      .post(`/lists/${readBody<{ id: string }>(created).id}/items`)
      .set('Authorization', `Bearer ${bob.accessToken}`)
      .send({ content: 'Before Sunrise' })
      .expect(201);
    const itemId = readBody<{ id: string }>(item).id;

    await request(app.getHttpServer())
      .patch(`/lists/items/${itemId}`)
      .set('Authorization', `Bearer ${dee.accessToken}`)
      .expect(404);
    await request(app.getHttpServer())
      .delete(`/lists/items/${itemId}`)
      .set('Authorization', `Bearer ${eve.accessToken}`)
      .expect(404);

    const stored = await prisma.listItem.findUniqueOrThrow({
      where: { id: itemId },
    });
    expect(stored.isCompleted).toBe(false);
    expect(stored.content).toBe('Before Sunrise');

    await request(app.getHttpServer())
      .patch(`/lists/items/${itemId}`)
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(200);
    const toggled = await prisma.listItem.findUniqueOrThrow({
      where: { id: itemId },
    });
    expect(toggled.isCompleted).toBe(true);
  });

  it('backfills existing pairs idempotently', async () => {
    const pairs = await Promise.all(
      [1, 2, 3].map(async (n) => {
        const left = await prisma.user.create({
          data: { email: `${prefix}-bf-${n}a@example.com`, name: `L${n}` },
        });
        const right = await prisma.user.create({
          data: { email: `${prefix}-bf-${n}b@example.com`, name: `R${n}` },
        });
        await prisma.user.update({
          where: { id: left.id },
          data: { partnerId: right.id },
        });
        await prisma.user.update({
          where: { id: right.id },
          data: { partnerId: left.id },
        });
        userIds.push(left.id, right.id);
        return { left, right };
      }),
    );

    const loner = await prisma.user.create({
      data: { email: `${prefix}-bf-loner@example.com`, name: 'Loner' },
    });
    userIds.push(loner.id);
    const orphanList = await prisma.partnerList.create({
      data: { type: 'TRAVEL', name: 'Solo', ownerId: loner.id },
    });
    const pairedList = await prisma.partnerList.create({
      data: { type: 'MILESTONES', name: 'Ours', ownerId: pairs[0].left.id },
    });

    const statements = loadBackfillStatements();
    for (const statement of statements) {
      await prisma.$executeRawUnsafe(statement);
    }

    const coupleIds = new Set<string>();
    for (const pair of pairs) {
      const left = await prisma.user.findUniqueOrThrow({
        where: { id: pair.left.id },
      });
      const right = await prisma.user.findUniqueOrThrow({
        where: { id: pair.right.id },
      });
      expect(left.coupleId).toBeTruthy();
      expect(left.coupleId).toBe(right.coupleId);
      coupleIds.add(left.coupleId!);
      const couple = await prisma.couple.findUniqueOrThrow({
        where: { id: left.coupleId! },
      });
      expect(couple.status).toBe('ACTIVE');
      expect([couple.userAId, couple.userBId].sort()).toEqual(
        [pair.left.id, pair.right.id].sort(),
      );
    }
    expect(coupleIds.size).toBe(3);

    const attached = await prisma.partnerList.findUniqueOrThrow({
      where: { id: pairedList.id },
    });
    const left = await prisma.user.findUniqueOrThrow({
      where: { id: pairs[0].left.id },
    });
    expect(attached.coupleId).toBe(left.coupleId);

    const solo = await prisma.partnerList.findUniqueOrThrow({
      where: { id: orphanList.id },
    });
    expect(solo.coupleId).toBeNull();

    for (const statement of statements) {
      await prisma.$executeRawUnsafe(statement);
    }

    const after = await prisma.couple.count({
      where: { id: { in: [...coupleIds] }, status: 'ACTIVE' },
    });
    expect(after).toBe(3);
    const still = await prisma.user.findUniqueOrThrow({
      where: { id: pairs[0].left.id },
    });
    expect(still.coupleId).toBe(left.coupleId);
  });

  it('computes daysTogether from the couple timezone and rejects bad profile patches', async () => {
    const ada = await login(app, `${prefix}-days-a@example.com`, 'Ada');
    const bob = await login(app, `${prefix}-days-b@example.com`, 'Bob');
    userIds.push(ada.user.id, bob.user.id);
    await pair(app, ada, bob);

    const patched = await request(app.getHttpServer())
      .patch('/couple')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({
        anniversaryDate: '2024-10-05',
        timezone: 'America/Sao_Paulo',
      })
      .expect(200);

    const patchedBody = readBody<{
      id: string;
      anniversaryDate: string;
      daysTogether: number;
    }>(patched);
    const couple = await prisma.couple.findUniqueOrThrow({
      where: { id: patchedBody.id },
    });
    expect(patchedBody.anniversaryDate).toBe('2024-10-05');
    expect(patchedBody.daysTogether).toBe(
      daysTogether({
        anniversaryDate: couple.anniversaryDate,
        pairedAt: couple.pairedAt,
        timezone: 'America/Sao_Paulo',
      }),
    );

    await request(app.getHttpServer())
      .patch('/couple')
      .set('Authorization', `Bearer ${bob.accessToken}`)
      .send({ timezone: 'Not/AZone' })
      .expect(400);

    await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ birthDate: '2999-01-01' })
      .expect(400);

    await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ birthDate: '1991-04-02', nickname: 'nope' })
      .expect(400);

    const saved = await request(app.getHttpServer())
      .patch('/users/me')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({ birthDate: '1991-04-02' })
      .expect(200);
    expect(readBody<{ birthDate: string }>(saved).birthDate).toBe('1991-04-02');

    const me = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .expect(200);
    expect(
      readBody<{ user: { birthDate: string | null } }>(me).user.birthDate,
    ).toBe('1991-04-02');

    const createdDate = await request(app.getHttpServer())
      .post('/couple/dates')
      .set('Authorization', `Bearer ${ada.accessToken}`)
      .send({
        title: 'Primeiro beijo',
        date: '2020-02-14',
        recurrence: 'YEARLY',
      })
      .expect(201);

    const foreign = await login(app, `${prefix}-days-z@example.com`, 'Zoe');
    const yuri = await login(app, `${prefix}-days-y@example.com`, 'Yuri');
    userIds.push(foreign.user.id, yuri.user.id);
    await pair(app, foreign, yuri);

    const dates = await request(app.getHttpServer())
      .get('/couple/dates')
      .set('Authorization', `Bearer ${foreign.accessToken}`)
      .expect(200);
    expect(dates.body).toEqual([]);

    await request(app.getHttpServer())
      .patch(`/couple/dates/${readBody<{ id: string }>(createdDate).id}`)
      .set('Authorization', `Bearer ${foreign.accessToken}`)
      .send({ title: 'Stolen' })
      .expect(404);
  });
});

function readBody<T>(response: { body: unknown }): T {
  return response.body as T;
}

async function login(app: INestApplication<App>, email: string, name: string) {
  const response = await request(app.getHttpServer())
    .post('/auth/dev-login')
    .send({ email, name })
    .expect(201);
  return response.body as AuthBody;
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

function loadBackfillStatements(): string[] {
  const sql = readFileSync(
    join(
      __dirname,
      '../prisma/migrations/20261005190000_add_couple_record/migration.sql',
    ),
    'utf8',
  );
  const match = sql.match(
    /-- BACKFILL_COUPLES_START\n([\s\S]*?)-- BACKFILL_COUPLES_END/,
  );
  if (!match) throw new Error('backfill block missing from migration');
  return match[1]
    .split(/;\s*\n/)
    .map((statement) => statement.trim())
    .filter((statement) => statement.length > 0);
}

async function cleanup(prisma: PrismaService, userIds: string[]) {
  if (userIds.length === 0) return;
  await prisma.listItem.deleteMany({
    where: { list: { ownerId: { in: userIds } } },
  });
  await prisma.partnerList.deleteMany({ where: { ownerId: { in: userIds } } });
  await prisma.coupleDate.deleteMany({
    where: {
      couple: {
        OR: [{ userAId: { in: userIds } }, { userBId: { in: userIds } }],
      },
    },
  });
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

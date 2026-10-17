import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { JwtStrategy } from '../auth/strategies/jwt.strategy';
import { PrismaService } from '../prisma';
import { UsersService } from '../users';
import { PairingController } from './pairing.controller';
import { PairingService } from './pairing.service';

const JWT_SECRET = 'pairing-received-test-secret';

interface StoredUser {
  id: string;
  email: string;
  name: string | null;
  partnerId: string | null;
  coupleId: string | null;
  pairingCode: string | null;
  pairingCodeExpiresAt: Date | null;
}

interface StoredRequest {
  id: string;
  requesterId: string;
  targetCode: string;
  createdAt: Date;
}

let uniqueFailures = 0;
let couplesCreated = 0;

function memoryPrisma(
  users: Map<string, StoredUser>,
  requests: StoredRequest[],
) {
  const api = {
    user: {
      findUnique: async ({
        where,
      }: {
        where: { id?: string; pairingCode?: string };
      }) => {
        const user = where.id
          ? users.get(where.id)
          : [...users.values()].find(
              (row) => row.pairingCode === where.pairingCode,
            );
        if (!user) return null;
        const partner = user.partnerId ? users.get(user.partnerId) : null;
        return {
          ...user,
          partner: partner
            ? {
                id: partner.id,
                name: partner.name,
                email: partner.email,
                picture: null,
              }
            : null,
        };
      },
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: Partial<StoredUser>;
      }) => {
        const user = users.get(where.id);
        if (!user) throw new Error('User not found');
        Object.assign(user, data);
        return user;
      },
    },
    pairingRequest: {
      findMany: async ({
        where,
      }: {
        where: { targetCode: string };
      }) =>
        requests
          .filter((row) => row.targetCode === where.targetCode)
          .map((row) => ({
            ...row,
            requester: {
              id: row.requesterId,
              name: users.get(row.requesterId)?.name ?? null,
            },
          })),
      findUnique: async ({ where }: { where: { id: string } }) =>
        requests.find((row) => row.id === where.id) ?? null,
      delete: async ({ where }: { where: { id: string } }) => {
        const index = requests.findIndex((row) => row.id === where.id);
        if (index < 0) throw new Error('not found');
        const [row] = requests.splice(index, 1);
        return row;
      },
      deleteMany: async ({
        where,
      }: {
        where: { OR?: Array<{ requesterId?: string }> };
      }) => {
        const ids = new Set(
          (where.OR ?? [])
            .map((clause) => clause.requesterId)
            .filter((id): id is string => Boolean(id)),
        );
        const before = requests.length;
        for (let index = requests.length - 1; index >= 0; index -= 1) {
          if (ids.has(requests[index].requesterId)) requests.splice(index, 1);
        }
        return { count: before - requests.length };
      },
    },
    couple: {
      create: async ({
        data,
      }: {
        data: { userAId: string; userBId: string; status: string };
      }) => {
        if (uniqueFailures > 0) {
          uniqueFailures -= 1;
          const error = new Error(
            'Unique constraint failed on the fields: (`userAId`)',
          );
          (error as { code: string }).code = 'P2002';
          throw error;
        }
        couplesCreated += 1;
        return { id: `couple-${couplesCreated}`, ...data };
      },
    },
    partnerList: {
      updateMany: async () => ({ count: 0 }),
    },
    $queryRaw: async () => [],
    $transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn(api),
  };
  return api as unknown as PrismaService;
}

describe('received pairing requests', () => {
  let app: INestApplication;
  const users = new Map<string, StoredUser>();
  const requests: StoredRequest[] = [];
  const tokens = new JwtService({
    secret: JWT_SECRET,
    signOptions: { expiresIn: '1h' },
  });

  function seed() {
    uniqueFailures = 0;
    couplesCreated = 0;
    users.clear();
    requests.splice(0, requests.length);
    const nextUsers: Array<[string, StoredUser]> = [
      [
        'user-a',
        {
          id: 'user-a',
          email: 'a@example.com',
          name: 'Ada',
          partnerId: null,
          coupleId: null,
          pairingCode: 'AAAAAA',
          pairingCodeExpiresAt: new Date('2026-12-01T00:00:00.000Z'),
        },
      ],
      [
        'user-b',
        {
          id: 'user-b',
          email: 'b@example.com',
          name: 'Bruno',
          partnerId: null,
          coupleId: null,
          pairingCode: 'BBBBBB',
          pairingCodeExpiresAt: new Date('2026-12-01T00:00:00.000Z'),
        },
      ],
      [
        'user-h',
        {
          id: 'user-h',
          email: 'h@example.com',
          name: 'Helena',
          partnerId: null,
          coupleId: null,
          pairingCode: 'HHHHHH',
          pairingCodeExpiresAt: new Date('2026-12-01T00:00:00.000Z'),
        },
      ],
      [
        'user-c',
        {
          id: 'user-c',
          email: 'c@example.com',
          name: 'Caio',
          partnerId: null,
          coupleId: null,
          pairingCode: 'CCCCCC',
          pairingCodeExpiresAt: new Date('2026-12-01T00:00:00.000Z'),
        },
      ],
      [
        'user-d',
        {
          id: 'user-d',
          email: 'd@example.com',
          name: 'Dora',
          partnerId: 'user-e',
          coupleId: 'couple-old',
          pairingCode: 'DDDDDD',
          pairingCodeExpiresAt: new Date('2026-12-01T00:00:00.000Z'),
        },
      ],
      [
        'user-e',
        {
          id: 'user-e',
          email: 'e@example.com',
          name: 'Eva',
          partnerId: 'user-d',
          coupleId: 'couple-old',
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
    ];
    for (const [id, user] of nextUsers) users.set(id, user);
    requests.push(
      {
        id: 'req-for-a',
        requesterId: 'user-h',
        targetCode: 'AAAAAA',
        createdAt: new Date('2026-01-02T00:00:00.000Z'),
      },
      {
        id: 'req-for-b',
        requesterId: 'user-a',
        targetCode: 'BBBBBB',
        createdAt: new Date('2026-01-03T00:00:00.000Z'),
      },
      {
        id: 'req-for-d',
        requesterId: 'user-h',
        targetCode: 'DDDDDD',
        createdAt: new Date('2026-01-04T00:00:00.000Z'),
      },
    );
  }

  beforeAll(async () => {
    process.env.JWT_SECRET = JWT_SECRET;
    seed();

    const moduleRef = await Test.createTestingModule({
      imports: [PassportModule.register({ defaultStrategy: 'jwt' })],
      controllers: [PairingController],
      providers: [
        PairingService,
        UsersService,
        JwtStrategy,
        { provide: PrismaService, useValue: memoryPrisma(users, requests) },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  beforeEach(() => {
    seed();
  });

  afterAll(async () => {
    await app.close();
  });

  function bearer(userId: string, email: string) {
    return `Bearer ${tokens.sign({ sub: userId, email })}`;
  }

  it('returns 401 without a token', async () => {
    await request(app.getHttpServer())
      .get('/pairing/requests/received')
      .expect(401);
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .expect(401);
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/decline')
      .expect(401);
  });

  it('lists only the caller’s received requests and leaks no code', async () => {
    const mine = await request(app.getHttpServer())
      .get('/pairing/requests/received')
      .query({ userId: 'user-b' })
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(200);

    expect(mine.body).toEqual([
      {
        id: 'req-for-a',
        createdAt: '2026-01-02T00:00:00.000Z',
        requester: { id: 'user-h', name: 'Helena' },
      },
    ]);
    const encoded = JSON.stringify(mine.body);
    expect(encoded).not.toContain('AAAAAA');
    expect(encoded).not.toContain('BBBBBB');
    expect(encoded).not.toContain('HHHHHH');
    expect(encoded).not.toContain('targetCode');
    expect(encoded).not.toContain('req-for-b');

    const other = await request(app.getHttpServer())
      .get('/pairing/requests/received')
      .set('Authorization', bearer('user-b', 'b@example.com'))
      .expect(200);
    expect(other.body.map((row: { id: string }) => row.id)).toEqual([
      'req-for-b',
    ]);
    expect(JSON.stringify(other.body)).not.toContain('req-for-a');
  });

  it('returns an empty list when nobody has requested the caller', async () => {
    const empty = await request(app.getHttpServer())
      .get('/pairing/requests/received')
      .set('Authorization', bearer('user-c', 'c@example.com'))
      .expect(200);
    expect(empty.body).toEqual([]);
  });

  it('returns 404 when accepting or declining a request that is not yours', async () => {
    await request(app.getHttpServer())
      .post('/pairing/requests/missing/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(404);
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-b/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(404);
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-b/decline')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(404);

    expect(requests.map((row) => row.id)).toContain('req-for-b');
    expect(users.get('user-b')?.partnerId).toBeNull();
  });

  it('returns 409 when the caller or the requester is already paired', async () => {
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-d/accept')
      .set('Authorization', bearer('user-d', 'd@example.com'))
      .expect(409);
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-d/decline')
      .set('Authorization', bearer('user-d', 'd@example.com'))
      .expect(409);
    expect(requests.map((row) => row.id)).toContain('req-for-d');

    requests.push({
      id: 'req-from-paired',
      requesterId: 'user-d',
      targetCode: 'CCCCCC',
      createdAt: new Date('2026-01-05T00:00:00.000Z'),
    });
    await request(app.getHttpServer())
      .post('/pairing/requests/req-from-paired/accept')
      .set('Authorization', bearer('user-c', 'c@example.com'))
      .expect(409);
    expect(users.get('user-c')?.partnerId).toBeNull();
    expect(requests.map((row) => row.id)).toContain('req-from-paired');
  });

  it('declines only the caller’s request', async () => {
    const declined = await request(app.getHttpServer())
      .post('/pairing/requests/req-for-b/decline')
      .set('Authorization', bearer('user-b', 'b@example.com'))
      .expect(201);

    expect(declined.body).toEqual({ message: 'Pedido recusado.' });
    expect(requests.map((row) => row.id)).not.toContain('req-for-b');
    expect(requests.map((row) => row.id)).toContain('req-for-a');

    const after = await request(app.getHttpServer())
      .get('/pairing/requests/received')
      .set('Authorization', bearer('user-b', 'b@example.com'))
      .expect(200);
    expect(after.body).toEqual([]);
  });

  it('accepts the caller’s request and does not return a code', async () => {
    const accepted = await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(201);

    expect(accepted.body.status).toBe('paired');
    expect(accepted.body.partner).toEqual({ id: 'user-h', name: 'Helena' });
    const encoded = JSON.stringify(accepted.body);
    expect(encoded).not.toContain('AAAAAA');
    expect(encoded).not.toContain('HHHHHH');
    expect(users.get('user-a')?.partnerId).toBe('user-h');
    expect(users.get('user-h')?.partnerId).toBe('user-a');
    expect(requests.map((row) => row.id)).not.toContain('req-for-a');
  });

  it('returns the paired result when the same accept is repeated', async () => {
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(201);

    const again = await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(201);

    expect(again.body.partner).toEqual({ id: 'user-h', name: 'Helena' });
    expect(JSON.stringify(again.body)).not.toContain('AAAAAA');
    expect(couplesCreated).toBe(1);
    expect(users.get('user-a')?.partnerId).toBe('user-h');
  });

  it('returns 404 when a paired user accepts an unknown request id', async () => {
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(201);

    const bogus = await request(app.getHttpServer())
      .post('/pairing/requests/does-not-exist/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(404);

    expect(bogus.body.message).toBe('Pedido de pareamento não encontrado.');
    expect(couplesCreated).toBe(1);
    expect(users.get('user-a')?.partnerId).toBe('user-h');
  });

  it('accepts once when two calls run together and never returns 500', async () => {
    const server = app.getHttpServer();
    const send = () =>
      request(server)
        .post('/pairing/requests/req-for-a/accept')
        .set('Authorization', bearer('user-a', 'a@example.com'));
    const [first, second] = await Promise.all([send(), send()]);

    for (const response of [first, second]) {
      expect(response.status).not.toBe(500);
      expect([201, 409]).toContain(response.status);
    }
    expect([first.status, second.status]).toContain(201);
    for (const response of [first, second].filter((row) => row.status === 201)) {
      expect(response.body.partner).toEqual({ id: 'user-h', name: 'Helena' });
      expect(JSON.stringify(response.body)).not.toContain('AAAAAA');
    }
    expect(couplesCreated).toBe(1);
    expect(users.get('user-a')?.partnerId).toBe('user-h');
    expect(users.get('user-h')?.partnerId).toBe('user-a');
  });

  it('returns 409 instead of 500 when the couple insert hits a unique constraint', async () => {
    uniqueFailures = 1;
    await request(app.getHttpServer())
      .post('/pairing/requests/req-for-a/accept')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(409);
    expect(users.get('user-a')?.partnerId).toBeNull();
    expect(couplesCreated).toBe(0);
  });
});

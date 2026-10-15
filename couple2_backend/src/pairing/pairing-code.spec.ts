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

const JWT_SECRET = 'pairing-code-test-secret';

interface StoredUser {
  id: string;
  email: string;
  partnerId: string | null;
  pairingCode: string | null;
  pairingCodeExpiresAt: Date | null;
}

function memoryPrisma(users: Map<string, StoredUser>) {
  return {
    user: {
      findUnique: async ({ where }: { where: { id?: string; pairingCode?: string } }) => {
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
                name: null,
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
  } as unknown as PrismaService;
}

describe('POST /pairing/code', () => {
  let app: INestApplication;
  let users: Map<string, StoredUser>;
  const tokens = new JwtService({
    secret: JWT_SECRET,
    signOptions: { expiresIn: '1h' },
  });

  beforeAll(async () => {
    process.env.JWT_SECRET = JWT_SECRET;
    users = new Map<string, StoredUser>([
      [
        'user-a',
        {
          id: 'user-a',
          email: 'a@example.com',
          partnerId: null,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
      [
        'user-b',
        {
          id: 'user-b',
          email: 'b@example.com',
          partnerId: null,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
      [
        'user-c',
        {
          id: 'user-c',
          email: 'c@example.com',
          partnerId: 'user-d',
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
    ]);

    const moduleRef = await Test.createTestingModule({
      imports: [PassportModule.register({ defaultStrategy: 'jwt' })],
      controllers: [PairingController],
      providers: [
        PairingService,
        UsersService,
        JwtStrategy,
        { provide: PrismaService, useValue: memoryPrisma(users) },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  function bearer(userId: string, email: string) {
    return `Bearer ${tokens.sign({ sub: userId, email })}`;
  }

  it('returns 401 without a token', async () => {
    await request(app.getHttpServer()).post('/pairing/code').expect(401);
  });

  it('creates a code only for the caller and repeats the same code', async () => {
    const first = await request(app.getHttpServer())
      .post('/pairing/code')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .send({ userId: 'user-b' })
      .expect(201);

    expect(first.body.pairingCode).toMatch(/^[A-Z0-9]{6}$/);
    expect(users.get('user-a')?.pairingCode).toBe(first.body.pairingCode);
    expect(users.get('user-b')?.pairingCode).toBeNull();

    const second = await request(app.getHttpServer())
      .post('/pairing/code')
      .set('Authorization', bearer('user-a', 'a@example.com'))
      .expect(201);

    expect(second.body.pairingCode).toBe(first.body.pairingCode);
    expect(second.body.pairingCodeExpiresAt).toBe(
      first.body.pairingCodeExpiresAt,
    );
    expect(users.get('user-b')?.pairingCode).toBeNull();
  });

  it('returns 409 when the caller is already paired', async () => {
    await request(app.getHttpServer())
      .post('/pairing/code')
      .set('Authorization', bearer('user-c', 'c@example.com'))
      .expect(409);
    expect(users.get('user-c')?.pairingCode).toBeNull();
  });
});

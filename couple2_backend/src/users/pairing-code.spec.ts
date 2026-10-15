const mockRandomInt = jest.fn();

jest.mock('node:crypto', () => {
  const actual =
    jest.requireActual<typeof import('node:crypto')>('node:crypto');
  return {
    ...actual,
    randomInt: (max: number) => mockRandomInt(max) as number,
  };
});

import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { UsersService } from './users.service';

interface StoredUser {
  id: string;
  partnerId: string | null;
  pairingCode: string | null;
  pairingCodeExpiresAt: Date | null;
}

function memoryPrisma(users: Map<string, StoredUser>) {
  return {
    user: {
      findUnique: async ({ where }: { where: Record<string, string> }) => {
        if (where.id) return users.get(where.id) ?? null;
        if (where.pairingCode) {
          return (
            [...users.values()].find(
              (user) => user.pairingCode === where.pairingCode,
            ) ?? null
          );
        }
        return null;
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
        if (data.pairingCode) {
          const clash = [...users.values()].find(
            (other) =>
              other.pairingCode === data.pairingCode && other.id !== user.id,
          );
          if (clash) {
            throw new Prisma.PrismaClientKnownRequestError(
              'Unique constraint failed',
              { code: 'P2002', clientVersion: 'test' },
            );
          }
        }
        Object.assign(user, data);
        return user;
      },
    },
  } as unknown as PrismaService;
}

describe('pairing code generation', () => {
  afterEach(() => {
    mockRandomInt.mockReset();
  });

  it('skips a code that already belongs to someone else', async () => {
    const users = new Map<string, StoredUser>([
      [
        'user-b',
        {
          id: 'user-b',
          partnerId: null,
          pairingCode: 'AAAAAA',
          pairingCodeExpiresAt: new Date('2099-01-01T00:00:00.000Z'),
        },
      ],
      [
        'user-a',
        {
          id: 'user-a',
          partnerId: null,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
    ]);
    let draws = 0;
    mockRandomInt.mockImplementation((max: number) => {
      const index = draws < 6 ? 0 : 1;
      draws += 1;
      return index % max;
    });

    const service = new UsersService(memoryPrisma(users));
    const updated = await service.generatePairingCodeForUser('user-a');

    expect(updated.pairingCode).toBe('BBBBBB');
    expect(users.get('user-b')?.pairingCode).toBe('AAAAAA');
    expect(draws).toBe(12);
  });

  it('stops after a bounded number of collisions', async () => {
    const users = new Map<string, StoredUser>([
      [
        'user-b',
        {
          id: 'user-b',
          partnerId: null,
          pairingCode: 'AAAAAA',
          pairingCodeExpiresAt: new Date('2099-01-01T00:00:00.000Z'),
        },
      ],
      [
        'user-a',
        {
          id: 'user-a',
          partnerId: null,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      ],
    ]);
    mockRandomInt.mockReturnValue(0);
    const service = new UsersService(memoryPrisma(users));

    await expect(service.generatePairingCodeForUser('user-a')).rejects.toThrow(
      'Failed to generate unique pairing code after max attempts',
    );
    expect(users.get('user-a')?.pairingCode).toBeNull();
    expect(mockRandomInt).toHaveBeenCalledTimes(60);
  });
});

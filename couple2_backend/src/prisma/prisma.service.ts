import { Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import * as admin from 'firebase-admin';
import { getFirestore } from '../firebase/firebase-admin';
import type {
  User,
  PartnerList,
  ListItem,
  PairingRequest,
} from '@prisma/client';

/**
 * Firestore-backed drop-in replacement for the former Prisma client.
 *
 * It deliberately mimics the small subset of the Prisma Client API that the
 * domain services already call (`user`, `partnerList`, `listItem`,
 * `pairingRequest` delegates plus `$transaction`) so that NONE of the service /
 * controller / domain code had to change. Only this data layer was swapped.
 *
 * Collections: users, partnerLists, listItems, pairingRequests.
 */

const COLLECTIONS = {
  user: 'users',
  partnerList: 'partnerLists',
  listItem: 'listItems',
  pairingRequest: 'pairingRequests',
} as const;

/** Recursively turn Firestore Timestamps back into JS Dates. */
function deTimestamp<T>(value: T): T {
  if (value == null) return value;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate() as unknown as T;
  }
  if (Array.isArray(value)) {
    return value.map((v) => deTimestamp(v)) as unknown as T;
  }
  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = deTimestamp(v);
    }
    return out as T;
  }
  return value;
}

function snapToData<T>(
  snap: FirebaseFirestore.DocumentSnapshot,
): T | null {
  if (!snap.exists) return null;
  return deTimestamp({ id: snap.id, ...snap.data() }) as T;
}

@Injectable()
export class PrismaService implements OnModuleInit {
  private _db!: FirebaseFirestore.Firestore;

  private get db(): FirebaseFirestore.Firestore {
    if (!this._db) {
      this._db = getFirestore();
      this._db.settings({ ignoreUndefinedProperties: true });
    }
    return this._db;
  }

  async onModuleInit() {
    // Touch the db getter so misconfiguration surfaces early (optional).
    // Kept lazy to allow the process to boot without credentials.
  }

  // --- helpers -------------------------------------------------------------

  private col(name: keyof typeof COLLECTIONS) {
    return this.db.collection(COLLECTIONS[name]);
  }

  private async findOneBy<T>(
    name: keyof typeof COLLECTIONS,
    field: string,
    value: unknown,
  ): Promise<T | null> {
    if (field === 'id') {
      const snap = await this.col(name).doc(String(value)).get();
      return snapToData<T>(snap);
    }
    const qs = await this.col(name).where(field, '==', value).limit(1).get();
    if (qs.empty) return null;
    return snapToData<T>(qs.docs[0]);
  }

  private whereField(where: Record<string, unknown>): {
    field: string;
    value: unknown;
  } {
    const field = Object.keys(where)[0];
    return { field, value: where[field] };
  }

  // --- user delegate -------------------------------------------------------

  user = {
    findUnique: async (args: {
      where: Record<string, unknown>;
      include?: { partner?: unknown; pairingRequestsSent?: unknown };
    }): Promise<any> => {
      const { field, value } = this.whereField(args.where);
      const user = await this.findOneBy<User>('user', field, value);
      if (!user) return null;
      return this.applyUserInclude(user, args.include);
    },

    findMany: async (): Promise<User[]> => {
      const qs = await this.col('user').get();
      return qs.docs.map((d) => snapToData<User>(d)!);
    },

    create: async (args: { data: Record<string, any> }): Promise<User> => {
      const id = randomUUID();
      const now = new Date();
      const doc = {
        name: null,
        picture: null,
        googleId: null,
        appleId: null,
        firebaseUid: null,
        pairingCode: null,
        pairingCodeExpiresAt: null,
        partnerId: null,
        ...args.data,
        createdAt: now,
        updatedAt: now,
      };
      await this.col('user').doc(id).set(doc);
      return deTimestamp({ id, ...doc }) as unknown as User;
    },

    update: async (args: {
      where: { id: string };
      data: Record<string, any>;
    }): Promise<User> => {
      const id = args.where.id;

      // Emulate the unique constraint on pairingCode so the retry loop in
      // UsersService.generatePairingCodeForUser keeps working.
      if (args.data.pairingCode) {
        const clash = await this.findOneBy<User>(
          'user',
          'pairingCode',
          args.data.pairingCode,
        );
        if (clash && clash.id !== id) {
          throw new Error('Unique constraint failed on the fields: (pairingCode)');
        }
      }

      const data = { ...args.data, updatedAt: new Date() };
      await this.col('user').doc(id).set(data, { merge: true });
      const snap = await this.col('user').doc(id).get();
      return snapToData<User>(snap)!;
    },
  };

  private async applyUserInclude(
    user: User,
    include?: { partner?: unknown; pairingRequestsSent?: unknown },
  ): Promise<any> {
    const result: Record<string, unknown> = { ...user };

    if (include?.partner) {
      result.partner = user.partnerId
        ? await this.findOneBy<User>('user', 'id', user.partnerId)
        : null;
    }

    if (include?.pairingRequestsSent) {
      const qs = await this.col('pairingRequest')
        .where('requesterId', '==', user.id)
        .get();
      result.pairingRequestsSent = qs.docs.map(
        (d) => snapToData<PairingRequest>(d)!,
      );
    }

    return result;
  }

  // --- partnerList delegate ------------------------------------------------

  partnerList = {
    findMany: async (args: {
      where?: { ownerId?: { in?: string[] } };
      include?: { items?: boolean };
      orderBy?: { createdAt?: 'asc' | 'desc' };
    }): Promise<any[]> => {
      const ids = args.where?.ownerId?.in ?? [];
      let lists: PartnerList[] = [];
      if (ids.length > 0) {
        const qs = await this.col('partnerList')
          .where('ownerId', 'in', ids)
          .get();
        lists = qs.docs.map((d) => snapToData<PartnerList>(d)!);
      } else {
        const qs = await this.col('partnerList').get();
        lists = qs.docs.map((d) => snapToData<PartnerList>(d)!);
      }

      if (args.orderBy?.createdAt) {
        const dir = args.orderBy.createdAt === 'desc' ? -1 : 1;
        lists.sort(
          (a, b) =>
            dir *
            (new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()),
        );
      }

      if (args.include?.items) {
        return Promise.all(lists.map((l) => this.attachItems(l)));
      }
      return lists;
    },

    create: async (args: {
      data: Record<string, any>;
      include?: { items?: boolean };
    }): Promise<any> => {
      const id = randomUUID();
      const now = new Date();
      const doc = { ...args.data, createdAt: now, updatedAt: now };
      await this.col('partnerList').doc(id).set(doc);
      const list = deTimestamp({ id, ...doc }) as unknown as PartnerList;
      if (args.include?.items) {
        return { ...list, items: [] };
      }
      return list;
    },

    findUnique: async (args: {
      where: { id: string };
    }): Promise<PartnerList | null> => {
      return this.findOneBy<PartnerList>('partnerList', 'id', args.where.id);
    },

    delete: async (args: { where: { id: string } }): Promise<PartnerList> => {
      const id = args.where.id;
      const snap = await this.col('partnerList').doc(id).get();
      const list = snapToData<PartnerList>(snap)!;
      // Cascade delete items (ListItem onDelete: Cascade in the old schema).
      const items = await this.col('listItem')
        .where('listId', '==', id)
        .get();
      const batch = this.db.batch();
      items.docs.forEach((d) => batch.delete(d.ref));
      batch.delete(this.col('partnerList').doc(id));
      await batch.commit();
      return list;
    },
  };

  private async attachItems(list: PartnerList): Promise<any> {
    const qs = await this.col('listItem')
      .where('listId', '==', list.id)
      .get();
    return { ...list, items: qs.docs.map((d) => snapToData<ListItem>(d)!) };
  }

  // --- listItem delegate ---------------------------------------------------

  listItem = {
    create: async (args: {
      data: Record<string, any>;
    }): Promise<ListItem> => {
      const id = randomUUID();
      const doc = {
        isCompleted: false,
        metadata: null,
        ...args.data,
        createdAt: new Date(),
      };
      await this.col('listItem').doc(id).set(doc);
      return deTimestamp({ id, ...doc }) as unknown as ListItem;
    },

    findUniqueOrThrow: async (args: {
      where: { id: string };
    }): Promise<ListItem> => {
      const item = await this.findOneBy<ListItem>(
        'listItem',
        'id',
        args.where.id,
      );
      if (!item) {
        throw new Error('No ListItem found');
      }
      return item;
    },

    update: async (args: {
      where: { id: string };
      data: Record<string, any>;
    }): Promise<ListItem> => {
      const id = args.where.id;
      await this.col('listItem').doc(id).set(args.data, { merge: true });
      const snap = await this.col('listItem').doc(id).get();
      return snapToData<ListItem>(snap)!;
    },

    delete: async (args: { where: { id: string } }): Promise<ListItem> => {
      const id = args.where.id;
      const snap = await this.col('listItem').doc(id).get();
      const item = snapToData<ListItem>(snap)!;
      await this.col('listItem').doc(id).delete();
      return item;
    },
  };

  // --- pairingRequest delegate --------------------------------------------

  pairingRequest = {
    create: async (args: {
      data: Record<string, any>;
    }): Promise<PairingRequest> => {
      const id = randomUUID();
      const doc = { ...args.data, createdAt: new Date() };
      await this.col('pairingRequest').doc(id).set(doc);
      return deTimestamp({ id, ...doc }) as unknown as PairingRequest;
    },

    findFirst: async (args: {
      where: { requesterId: string; targetCode: string };
    }): Promise<PairingRequest | null> => {
      const qs = await this.col('pairingRequest')
        .where('requesterId', '==', args.where.requesterId)
        .where('targetCode', '==', args.where.targetCode)
        .limit(1)
        .get();
      if (qs.empty) return null;
      return snapToData<PairingRequest>(qs.docs[0]);
    },

    deleteMany: async (args: {
      where: { requesterId?: string; OR?: { requesterId: string }[] };
    }): Promise<{ count: number }> => {
      const requesterIds = args.where.OR
        ? args.where.OR.map((o) => o.requesterId)
        : args.where.requesterId
          ? [args.where.requesterId]
          : [];

      let count = 0;
      const batch = this.db.batch();
      for (const rid of requesterIds) {
        const qs = await this.col('pairingRequest')
          .where('requesterId', '==', rid)
          .get();
        qs.docs.forEach((d) => {
          batch.delete(d.ref);
          count++;
        });
      }
      if (count > 0) await batch.commit();
      return { count };
    },
  };

  // --- transaction ---------------------------------------------------------

  /**
   * NOTE: Prisma's interactive transactions are emulated by running the
   * callback sequentially against the same delegates. This is NOT atomic on
   * Firestore. The pairing flows are low-contention, so this is acceptable for
   * now; revisit with `db.runTransaction` if stronger guarantees are needed.
   */
  async $transaction<R>(fn: (tx: this) => Promise<R>): Promise<R> {
    return fn(this);
  }
}

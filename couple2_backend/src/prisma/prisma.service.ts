import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

/** Drop Prisma's `schema` query param so node-postgres does not send it. */
function connectionStringForPg(databaseUrl: string): string {
  const url = new URL(databaseUrl);
  url.searchParams.delete('schema');
  return url.toString();
}

/**
 * Prisma client for the local Supabase Postgres database.
 *
 * Domain services keep using the delegate API (`user`, `partnerList`,
 * `listItem`, `pairingRequest`, `$transaction`). This service is the real
 * client — not a Firestore shim — and does not need Firebase credentials.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly pool: Pool;

  constructor() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error(
        'DATABASE_URL is not set. Start local Supabase with `supabase start` ' +
          'and point DATABASE_URL at its Postgres (see .env.example).',
      );
    }

    // Prisma CLI understands `?schema=public`. node-postgres forwards unknown
    // URI params to the server, which rejects `schema`.
    const pool = new Pool({
      connectionString: connectionStringForPg(connectionString),
    });
    super({ adapter: new PrismaPg(pool) });
    this.pool = pool;
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
    await this.pool.end();
  }
}

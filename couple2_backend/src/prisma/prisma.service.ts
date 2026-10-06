import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { Pool, PoolConfig } from 'pg';
import { rootCertificates } from 'tls';

const SUPABASE_ROOT_CANDIDATES = [
  process.env.DATABASE_SSL_ROOT_CERT,
  resolve(process.cwd(), 'certs/supabase-root-2021.crt'),
  '/usr/local/share/ca-certificates/supabase-root-2021.crt',
].filter((path): path is string => Boolean(path));

/** Drop Prisma's `schema` query param so node-postgres does not send it. */
export function pgPoolConfig(databaseUrl: string): PoolConfig {
  const url = new URL(databaseUrl);
  const sslmode = url.searchParams.get('sslmode')?.toLowerCase();
  const sslFlag = url.searchParams.get('ssl')?.toLowerCase();
  url.searchParams.delete('schema');
  // Prisma-only. node-postgres does not use it, and Postgres rejects it.
  url.searchParams.delete('pgbouncer');

  const disableTls =
    sslmode === 'disable' || sslFlag === 'false' || sslFlag === '0';
  const requireTls =
    !disableTls && (Boolean(sslmode) || sslFlag === 'true' || sslFlag === '1');

  if (!requireTls) {
    return disableTls
      ? { connectionString: url.toString(), ssl: false }
      : { connectionString: url.toString() };
  }

  // pg-connection-string treats sslmode=require as verify-full and would
  // override an explicit ssl option. Apply verification here instead.
  url.searchParams.delete('sslmode');
  url.searchParams.delete('ssl');
  url.searchParams.delete('sslrootcert');
  url.searchParams.delete('sslcert');
  url.searchParams.delete('sslkey');
  url.searchParams.delete('uselibpqcompat');

  const extraCa = loadBundledSupabaseRootCa();
  return {
    connectionString: url.toString(),
    ssl: {
      rejectUnauthorized: true,
      ca: extraCa ? [...rootCertificates, extraCa] : [...rootCertificates],
    },
  };
}

/**
 * Supabase's pooler certificate chains to Supabase Root 2021 CA, which is
 * not in the public CA bundle. Trust that root and keep verification on.
 */
export function loadBundledSupabaseRootCa(): string | undefined {
  for (const path of SUPABASE_ROOT_CANDIDATES) {
    if (existsSync(path)) {
      return readFileSync(path, 'utf8');
    }
  }
  return undefined;
}

function usesSupabaseTls(databaseUrl: string): boolean {
  try {
    const host = new URL(databaseUrl).hostname;
    return host.endsWith('.supabase.com') || host.endsWith('.supabase.co');
  } catch {
    return false;
  }
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
  private readonly logger = new Logger(PrismaService.name);
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
    const config = pgPoolConfig(connectionString);
    const pool = new Pool(config);
    super({ adapter: new PrismaPg(pool) });
    this.pool = pool;

    if (
      usesSupabaseTls(connectionString) &&
      config.ssl &&
      typeof config.ssl === 'object' &&
      !loadBundledSupabaseRootCa()
    ) {
      this.logger.warn(
        'Supabase DATABASE_URL uses TLS but Supabase Root 2021 CA was not found. Certificate verification stays enabled.',
      );
    }
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
    await this.pool.end();
  }
}

import { readFileSync } from 'fs';
import { resolve } from 'path';
import { ConnectionOptions } from 'tls';
import { pgPoolConfig } from './prisma.service';

const supabaseRoot = readFileSync(
  resolve(process.cwd(), 'certs/supabase-root-2021.crt'),
  'utf8',
);

function sslOf(databaseUrl: string): ConnectionOptions {
  const ssl = pgPoolConfig(databaseUrl).ssl;
  expect(ssl).toEqual(expect.objectContaining({ rejectUnauthorized: true }));
  return ssl as ConnectionOptions;
}

describe('pgPoolConfig', () => {
  it('does not enable TLS for the local Supabase URL', () => {
    const config = pgPoolConfig(
      'postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public',
    );

    expect(config.ssl).toBeUndefined();
    expect(config.connectionString).not.toContain('schema=');
  });

  it('verifies Supabase TLS and trusts Supabase Root 2021 CA', () => {
    const config = pgPoolConfig(
      'postgresql://postgres.ref:secret@aws-0-us-west-2.pooler.supabase.com:5432/postgres?schema=public&sslmode=require&pgbouncer=true',
    );
    const ssl = sslOf(
      'postgresql://postgres.ref:secret@aws-0-us-west-2.pooler.supabase.com:5432/postgres?schema=public&sslmode=require&pgbouncer=true',
    );

    expect(ssl.rejectUnauthorized).toBe(true);
    expect(ssl.ca).toEqual(expect.arrayContaining([supabaseRoot]));
    expect(config.connectionString).not.toContain('sslmode');
    expect(config.connectionString).not.toContain('pgbouncer');
    expect(config.connectionString).not.toContain('schema=');
    expect(JSON.stringify(config.ssl)).not.toContain(
      '"rejectUnauthorized":false',
    );
  });

  it('does not honor sslmode=no-verify', () => {
    const ssl = sslOf(
      'postgresql://postgres:secret@aws-0-us-west-2.pooler.supabase.com:6543/postgres?sslmode=no-verify&pgbouncer=true',
    );

    expect(ssl.rejectUnauthorized).toBe(true);
    expect(ssl.ca).toEqual(expect.arrayContaining([supabaseRoot]));
  });
});

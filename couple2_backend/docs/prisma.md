# Prisma ORM Setup

## Overview

This project uses **Prisma 7** with PostgreSQL. Prisma 7 introduced a new architecture where the query engine is written in TypeScript (instead of Rust) and requires explicit driver adapters for database connections.

## Version Info

- Prisma: `^7.2.0`
- Adapter: `@prisma/adapter-pg`
- Driver: `pg`

## File Structure

```
├── prisma/
│   ├── schema.prisma          # Data models and generator config
│   └── migrations/            # Generated migration files
├── prisma.config.ts           # Prisma 7 runtime configuration
├── src/
│   └── prisma/
│       ├── prisma.service.ts  # NestJS injectable service
│       ├── prisma.module.ts   # Global module
│       └── index.ts           # Barrel export
```

## Configuration Files

### prisma.config.ts

Prisma 7 uses this file for runtime configuration. The `DATABASE_URL` is read here (not in schema.prisma).

```typescript
import "dotenv/config";
import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: process.env["DATABASE_URL"],
  },
});
```

### prisma/schema.prisma

Contains model definitions. Note: `url` is NOT set in datasource (Prisma 7 requirement).

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  googleId  String?  @unique
  appleId   String?  @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Pairing code for connecting with partner
  pairingCode          String?   @unique @db.Char(6)
  pairingCodeExpiresAt DateTime?

  // Self-referencing relation for partner/couple
  partnerId String? @unique
  partner   User?   @relation("CouplePartner", fields: [partnerId], references: [id])
  partnerOf User?   @relation("CouplePartner")

  @@map("users")
}
```

## NestJS Integration

### PrismaService (src/prisma/prisma.service.ts)

The service extends `PrismaClient` and uses the Prisma 7 adapter pattern with a `pg` connection pool.

```typescript
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private pool: Pool;

  constructor() {
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });
    const adapter = new PrismaPg(pool);
    super({ adapter });
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
```

**Key points:**
- `onModuleInit`: Connects to DB when NestJS app starts
- `onModuleDestroy`: Disconnects and closes pool on shutdown
- Pool must be explicitly closed to prevent connection leaks

### PrismaModule (src/prisma/prisma.module.ts)

Marked as `@Global()` so `PrismaService` is available throughout the app without re-importing.

```typescript
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

### Usage in Services

Import `PrismaService` via constructor injection:

```typescript
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(data: { email: string; name?: string }) {
    return this.prisma.user.create({ data });
  }

  async findAll() {
    return this.prisma.user.findMany();
  }

  async findOne(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }
}
```

## Environment Variables

Required in `.env`:

```bash
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
```

That URL is the Postgres published by `supabase start` (repo root). The API container uses `host.docker.internal` instead of `127.0.0.1`; `docker-compose.yml` sets it.

## CLI Commands

### Generate Prisma Client
```bash
npx prisma generate
```
Run after any schema.prisma changes. Regenerates types in `node_modules/@prisma/client`.

### Create Migration (Development)
```bash
npx prisma migrate dev --name <migration_name>
```
- Generates SQL migration file
- Applies migration to database
- Regenerates Prisma Client

### Apply Migrations (Production)
```bash
npx prisma migrate deploy
```
Only applies pending migrations. Used in Docker CMD.

### Reset Database
```bash
npx prisma migrate reset
```
Drops database, recreates it, applies all migrations. **Deletes all data.**

### Check Migration Status
```bash
npx prisma migrate status
```

### Open Prisma Studio
```bash
npx prisma studio
```
Opens web UI at `http://localhost:5555` for browsing/editing data.

### Introspect Existing Database
```bash
npx prisma db pull
```
Generates schema from existing database structure.

### Push Schema Without Migration
```bash
npx prisma db push
```
Syncs schema to database without creating migration files. Useful for prototyping.

## Models Reference

### User

| Field                | Type      | Attributes                  | Description                              |
|----------------------|-----------|-----------------------------| -----------------------------------------|
| id                   | String    | @id @default(uuid())        | Primary key, UUID                        |
| email                | String    | @unique                     | User email (unique)                      |
| name                 | String?   | optional                    | Display name                             |
| googleId             | String?   | @unique                     | Google OAuth subject ID                  |
| appleId              | String?   | @unique                     | Apple Sign-In subject ID                 |
| createdAt            | DateTime  | @default(now())             | Account creation timestamp               |
| updatedAt            | DateTime  | @updatedAt                  | Last update timestamp                    |
| pairingCode          | String?   | @unique @db.Char(6)         | 6-char code for partner pairing          |
| pairingCodeExpiresAt | DateTime? | optional                    | Pairing code expiration (30 days TTL)    |
| partnerId            | String?   | @unique                     | FK to partner user (1:1 relation)        |
| partner              | User?     | @relation("CouplePartner")  | The user's partner                       |
| partnerOf            | User?     | @relation("CouplePartner")  | Inverse relation                         |

Table name: `users` (via `@@map("users")`)

#### Partner Relation

The User model has a **self-referencing 1:1 relation** for the couple/partner feature:

```typescript
// Link two users as partners
await this.prisma.user.update({
  where: { id: userAId },
  data: { partnerId: userBId },
});

// Get user with partner data
const user = await this.prisma.user.findUnique({
  where: { id: userId },
  include: { partner: true },
});

// Check if user has a partner
if (user.partnerId) {
  console.log('User is coupled with:', user.partner?.email);
}
```

#### Social Auth Lookups

```typescript
// Find user by Google ID
await this.prisma.user.findUnique({ where: { googleId: 'google-sub-id' } });

// Find user by Apple ID
await this.prisma.user.findUnique({ where: { appleId: 'apple-sub-id' } });

// Link Google account to existing user
await this.prisma.user.update({
  where: { id: userId },
  data: { googleId: 'google-sub-id' },
});
```

#### Pairing Code System

Users without a partner get a **6-character alphanumeric pairing code** for connecting with their partner.

**Configuration:**
- Code length: 6 characters
- Character set: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (excludes O/0/I/1 for clarity)
- TTL: 30 days
- Auto-generated on login if missing or expired

**UsersService Methods:**

```typescript
// Generate/refresh pairing code for a user
await this.usersService.generatePairingCodeForUser(userId);

// Ensure user has a valid code (generates if missing/expired)
await this.usersService.ensurePairingCode(userId);

// Find user by their pairing code
const user = await this.usersService.findByPairingCode('XJ92L1');

// Check if code is valid
const isValid = this.usersService.isPairingCodeValid(user);

// Clear pairing code (after successful pairing)
await this.usersService.clearPairingCode(userId);
```

**Auto-generation on Login:**

When a user logs in via `/auth/google` or `/auth/apple`:
1. If user has a partner → no pairing code needed
2. If user has no partner:
   - If pairing code exists and is valid → return existing code
   - If pairing code is missing or expired → generate new code

**Auth Response includes pairing code:**

```json
{
  "accessToken": "...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John",
    "partnerId": null,
    "pairingCode": "XJ92L1",
    "pairingCodeExpiresAt": "2024-02-18T12:00:00.000Z"
  }
}
```

### PairingRequest

Stores pending pairing requests for the double handshake system.

| Field       | Type     | Attributes               | Description                         |
|-------------|----------|--------------------------|-------------------------------------|
| id          | String   | @id @default(uuid())     | Primary key                         |
| requesterId | String   |                          | FK to user who made the request     |
| targetCode  | String   | @db.Char(6)              | The pairing code entered            |
| createdAt   | DateTime | @default(now())          | When request was created            |

Table name: `pairing_requests` (via `@@map("pairing_requests")`)

**Unique Constraint:** `@@unique([requesterId, targetCode])` - One user can only have one pending request per target code.

**Cascade Delete:** Requests are deleted when the requester user is deleted.

See [docs/pairing.md](./pairing.md) for the complete double handshake flow.

## Adding New Models

1. Define model in `prisma/schema.prisma`:
```prisma
model Post {
  id        String   @id @default(uuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("posts")
}
```

2. Add relation to User model:
```prisma
model User {
  // ... existing fields
  posts Post[]
}
```

3. Generate migration:
```bash
npx prisma migrate dev --name add_posts
```

4. Create corresponding NestJS module/service.

## Common Prisma Operations

### Create
```typescript
await this.prisma.user.create({
  data: { email: 'user@example.com', name: 'John' }
});
```

### Create Many
```typescript
await this.prisma.user.createMany({
  data: [
    { email: 'user1@example.com' },
    { email: 'user2@example.com' }
  ]
});
```

### Find Unique
```typescript
await this.prisma.user.findUnique({ where: { id: 'uuid' } });
await this.prisma.user.findUnique({ where: { email: 'user@example.com' } });
```

### Find Many with Filters
```typescript
await this.prisma.user.findMany({
  where: { name: { contains: 'John' } },
  orderBy: { createdAt: 'desc' },
  take: 10,
  skip: 0
});
```

### Update
```typescript
await this.prisma.user.update({
  where: { id: 'uuid' },
  data: { name: 'Updated Name' }
});
```

### Delete
```typescript
await this.prisma.user.delete({ where: { id: 'uuid' } });
```

### Transactions
```typescript
await this.prisma.$transaction([
  this.prisma.user.create({ data: { email: 'a@example.com' } }),
  this.prisma.user.create({ data: { email: 'b@example.com' } })
]);
```

### Raw Queries
```typescript
const result = await this.prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;
```

## Docker Integration

The Dockerfile's last stage is `production` (the Railway image). It installs production dependencies with `npm ci --omit=dev`, generates the Prisma client, copies `dist` plus `prisma/schema` and `prisma/migrations`, and starts as a non-root user:

```dockerfile
CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && exec node dist/main"]
```

`npm run start:prod` and `npm run prod` are the same sequence (`prisma migrate deploy && node dist/main`). `prisma` and `dotenv` are runtime dependencies so that command works without devDependencies.

Development (compose pins `--target development`) waits for Supabase Postgres, then migrates and watches:

```dockerfile
CMD ["sh", "-c", "node scripts/wait-for-db.mjs && npx prisma migrate deploy && npm run dev"]
```

## Troubleshooting

### "Cannot find module '@prisma/client'"
Run `npx prisma generate` to regenerate the client.

### "Environment variable not found: DATABASE_URL"
Ensure `.env` file exists and contains `DATABASE_URL`.

### Connection refused
- From the repo root, check `supabase status` (Postgres should be on port 54322)
- Host API: `DATABASE_URL` host is `127.0.0.1`
- API container: `DATABASE_URL` host is `host.docker.internal` (set by docker-compose.yml)

### Migration conflicts
If migrations get out of sync:
```bash
npx prisma migrate reset  # Warning: deletes all data
```

### Type errors after schema changes
Regenerate client and restart TypeScript server:
```bash
npx prisma generate
# In VSCode: Cmd+Shift+P -> "TypeScript: Restart TS Server"
```

npx prisma migrate dev --name add_user_picture
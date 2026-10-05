-- CreateEnum
CREATE TYPE "CoupleStatus" AS ENUM ('ACTIVE', 'ENDED');

-- CreateEnum
CREATE TYPE "CoupleDateType" AS ENUM ('CUSTOM');

-- CreateEnum
CREATE TYPE "Recurrence" AS ENUM ('NONE', 'YEARLY');

-- AlterTable
ALTER TABLE "partner_lists" ADD COLUMN     "coupleId" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "birthDate" DATE,
ADD COLUMN     "coupleId" TEXT;

-- CreateTable
CREATE TABLE "couples" (
    "id" TEXT NOT NULL,
    "userAId" TEXT NOT NULL,
    "userBId" TEXT NOT NULL,
    "status" "CoupleStatus" NOT NULL DEFAULT 'ACTIVE',
    "pairedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMP(3),
    "anniversaryDate" DATE,
    "timezone" TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "couples_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "couple_dates" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "type" "CoupleDateType" NOT NULL DEFAULT 'CUSTOM',
    "title" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "recurrence" "Recurrence" NOT NULL DEFAULT 'YEARLY',
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "couple_dates_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "couples_userAId_status_idx" ON "couples"("userAId", "status");

-- CreateIndex
CREATE INDEX "couples_userBId_status_idx" ON "couples"("userBId", "status");

-- CreateIndex
CREATE INDEX "couple_dates_coupleId_idx" ON "couple_dates"("coupleId");

-- CreateIndex
CREATE INDEX "partner_lists_coupleId_idx" ON "partner_lists"("coupleId");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couples" ADD CONSTRAINT "couples_userAId_fkey" FOREIGN KEY ("userAId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couples" ADD CONSTRAINT "couples_userBId_fkey" FOREIGN KEY ("userBId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couple_dates" ADD CONSTRAINT "couple_dates_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_lists" ADD CONSTRAINT "partner_lists_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- BACKFILL_COUPLES_START
-- Idempotent backfill for pairs that existed before the couple record.
-- One ACTIVE couple per mutual pair (smaller user id is userA). Lists of
-- unpaired users stay coupleId NULL and are attached on the next pairing.
INSERT INTO "couples" (
    "id",
    "userAId",
    "userBId",
    "status",
    "pairedAt",
    "timezone",
    "createdAt",
    "updatedAt"
)
SELECT
    gen_random_uuid()::text,
    u."id",
    u."partnerId",
    'ACTIVE'::"CoupleStatus",
    LEAST(u."updatedAt", p."updatedAt"),
    'America/Sao_Paulo',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "users" u
INNER JOIN "users" p
    ON p."id" = u."partnerId"
   AND p."partnerId" = u."id"
WHERE u."id" < u."partnerId"
  AND NOT EXISTS (
    SELECT 1
    FROM "couples" c
    WHERE c."status" = 'ACTIVE'
      AND (
        c."userAId" IN (u."id", u."partnerId")
        OR c."userBId" IN (u."id", u."partnerId")
      )
  );

UPDATE "users" u
SET "coupleId" = c."id"
FROM "couples" c
WHERE c."status" = 'ACTIVE'
  AND u."coupleId" IS NULL
  AND u."partnerId" IS NOT NULL
  AND (c."userAId" = u."id" OR c."userBId" = u."id");

UPDATE "partner_lists" pl
SET "coupleId" = u."coupleId"
FROM "users" u
WHERE pl."ownerId" = u."id"
  AND pl."coupleId" IS NULL
  AND u."coupleId" IS NOT NULL;
-- BACKFILL_COUPLES_END

-- One ACTIVE couple per user. ENDED rows stay, so the same pair can re-pair
-- into a new couple. Prisma does not model partial unique indexes; do not drop
-- these in a later generated migration.
CREATE UNIQUE INDEX "couples_userAId_active_key" ON "couples" ("userAId") WHERE "status" = 'ACTIVE';

CREATE UNIQUE INDEX "couples_userBId_active_key" ON "couples" ("userBId") WHERE "status" = 'ACTIVE';

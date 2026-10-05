-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('IOS', 'ANDROID', 'WEB');

-- CreateEnum
CREATE TYPE "ActivityType" AS ENUM ('LIST_CREATED', 'LIST_ITEM_ADDED', 'LIST_ITEM_COMPLETED', 'COUPLE_DATE_UPCOMING', 'COUPLE_UPDATED', 'QUESTION_ANSWERED', 'QUESTION_UNLOCKED', 'MOOD_SHARED', 'NUDGE_SENT', 'DATE_PLAN_PROPOSED', 'DATE_PLAN_ACCEPTED', 'DATE_PLAN_DECLINED', 'DATE_PLAN_COUNTERED', 'DATE_PLAN_CANCELLED', 'DATE_PLAN_DONE');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "feedSeenAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "device_tokens" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" "DevicePlatform" NOT NULL,
    "appVersion" TEXT,
    "locale" TEXT,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "activity_events" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "actorId" TEXT,
    "type" "ActivityType" NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "payload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "activity_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_preferences" (
    "userId" TEXT NOT NULL,
    "pushEnabled" BOOLEAN NOT NULL DEFAULT true,
    "lists" BOOLEAN NOT NULL DEFAULT true,
    "importantDates" BOOLEAN NOT NULL DEFAULT true,
    "dailyQuestion" BOOLEAN NOT NULL DEFAULT true,
    "mood" BOOLEAN NOT NULL DEFAULT true,
    "nudges" BOOLEAN NOT NULL DEFAULT true,
    "datePlans" BOOLEAN NOT NULL DEFAULT true,
    "quietStartMin" INTEGER,
    "quietEndMin" INTEGER,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("userId")
);

-- CreateIndex
CREATE UNIQUE INDEX "device_tokens_token_key" ON "device_tokens"("token");

-- CreateIndex
CREATE INDEX "device_tokens_userId_idx" ON "device_tokens"("userId");

-- CreateIndex
CREATE INDEX "activity_events_coupleId_createdAt_idx" ON "activity_events"("coupleId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "activity_events_coupleId_type_entityId_idx" ON "activity_events"("coupleId", "type", "entityId");

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_preferences" ADD CONSTRAINT "notification_preferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- One COUPLE_DATE_UPCOMING row per couple, entity, and occurrence date.
-- Prisma does not model this expression index; do not drop it in a later
-- generated migration. Re-running the 09:00 job hits this and does not duplicate.
CREATE UNIQUE INDEX "activity_events_upcoming_dedupe_idx"
ON "activity_events" ("coupleId", "type", "entityId", (("payload"->>'occurrenceDate')))
WHERE "type" = 'COUPLE_DATE_UPCOMING';

-- CreateEnum
CREATE TYPE "ListVisibility" AS ENUM ('SHARED', 'PRIVATE_FROM_PARTNER');

-- Existing lists stay shared. The default backfills every current row.
ALTER TABLE "partner_lists" ADD COLUMN "visibility" "ListVisibility" NOT NULL DEFAULT 'SHARED';

-- CreateIndex
CREATE INDEX "partner_lists_coupleId_visibility_idx" ON "partner_lists"("coupleId", "visibility");

-- CreateEnum
CREATE TYPE "DatePlanStatus" AS ENUM ('PROPOSED', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'DONE', 'EXPIRED');

-- CreateTable
CREATE TABLE "date_plans" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "proposerId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "location" TEXT,
    "scheduledAt" TIMESTAMP(3) NOT NULL,
    "status" "DatePlanStatus" NOT NULL DEFAULT 'PROPOSED',
    "responseNote" TEXT,
    "respondedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "reminderSentAt" TIMESTAMP(3),
    "sourceListItemId" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "date_plans_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "date_plans_title_len" CHECK (char_length("title") BETWEEN 1 AND 80),
    CONSTRAINT "date_plans_description_len" CHECK ("description" IS NULL OR char_length("description") <= 500),
    CONSTRAINT "date_plans_location_len" CHECK ("location" IS NULL OR char_length("location") <= 120),
    CONSTRAINT "date_plans_response_note_len" CHECK ("responseNote" IS NULL OR char_length("responseNote") <= 140)
);

-- CreateIndex
CREATE INDEX "date_plans_coupleId_status_scheduledAt_idx" ON "date_plans"("coupleId", "status", "scheduledAt");

-- AddForeignKey
ALTER TABLE "date_plans" ADD CONSTRAINT "date_plans_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

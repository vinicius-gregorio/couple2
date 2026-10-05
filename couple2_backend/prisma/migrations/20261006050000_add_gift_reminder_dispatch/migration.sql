-- CreateTable
CREATE TABLE "gift_reminder_dispatches" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "occurrenceDate" DATE NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gift_reminder_dispatches_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gift_reminder_dispatches_userId_kind_occurrenceDate_key" ON "gift_reminder_dispatches"("userId", "kind", "occurrenceDate");

-- AddForeignKey
ALTER TABLE "gift_reminder_dispatches" ADD CONSTRAINT "gift_reminder_dispatches_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

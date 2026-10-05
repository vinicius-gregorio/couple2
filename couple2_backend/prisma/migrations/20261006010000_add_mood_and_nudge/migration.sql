-- CreateEnum
CREATE TYPE "MoodLevel" AS ENUM ('GREAT', 'GOOD', 'OK', 'LOW', 'BAD');

-- CreateEnum
CREATE TYPE "NudgeKind" AS ENUM ('THINKING_OF_YOU', 'HUG', 'KISS', 'MISS_YOU');

-- CreateTable
CREATE TABLE "mood_checkins" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "mood" "MoodLevel" NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mood_checkins_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "mood_checkins_note_len" CHECK ("note" IS NULL OR char_length("note") <= 140)
);

-- CreateTable
CREATE TABLE "nudges" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "kind" "NudgeKind" NOT NULL,
    "message" TEXT,
    "seenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nudges_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "nudges_message_len" CHECK ("message" IS NULL OR char_length("message") <= 80)
);

-- CreateIndex
CREATE INDEX "mood_checkins_coupleId_userId_createdAt_idx" ON "mood_checkins"("coupleId", "userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "nudges_receiverId_createdAt_idx" ON "nudges"("receiverId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "nudges_senderId_createdAt_idx" ON "nudges"("senderId", "createdAt");

-- AddForeignKey
ALTER TABLE "mood_checkins" ADD CONSTRAINT "mood_checkins_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mood_checkins" ADD CONSTRAINT "mood_checkins_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nudges" ADD CONSTRAINT "nudges_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nudges" ADD CONSTRAINT "nudges_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nudges" ADD CONSTRAINT "nudges_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

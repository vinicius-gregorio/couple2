-- AlterTable
ALTER TABLE "pairing_requests" ALTER COLUMN "targetCode" SET DATA TYPE TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "firebaseUid" TEXT,
ALTER COLUMN "pairingCode" SET DATA TYPE TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "users_firebaseUid_key" ON "users"("firebaseUid");

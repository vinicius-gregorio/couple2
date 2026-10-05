-- CreateEnum
CREATE TYPE "ListType" AS ENUM ('SHOPPING_CART', 'MOVIES', 'MILESTONES', 'TRAVEL');

-- CreateTable
CREATE TABLE "partner_lists" (
    "id" TEXT NOT NULL,
    "type" "ListType" NOT NULL,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_lists_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "list_items" (
    "id" TEXT NOT NULL,
    "listId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "metadata" JSONB,
    "isCompleted" BOOLEAN NOT NULL DEFAULT false,
    "addedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "list_items_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "partner_lists" ADD CONSTRAINT "partner_lists_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "list_items" ADD CONSTRAINT "list_items_listId_fkey" FOREIGN KEY ("listId") REFERENCES "partner_lists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- PostgreSQL cannot use a new enum value in the same transaction that adds it.
-- Prisma runs each migration inside a transaction, so GIFT_IDEAS is added alone.
ALTER TYPE "ListType" ADD VALUE 'GIFT_IDEAS';

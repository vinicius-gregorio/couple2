import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

/** Smaller id is userA so a pair has one canonical row. */
export function canonicalPair(
  id1: string,
  id2: string,
): {
  userAId: string;
  userBId: string;
} {
  return id1 < id2
    ? { userAId: id1, userBId: id2 }
    : { userAId: id2, userBId: id1 };
}

/**
 * Creates the ACTIVE couple and writes partnerId + coupleId on both users.
 * Lists that still have coupleId NULL (never attached, including orphans from
 * before this user was paired) are claimed by the new couple. Lists that still
 * point at an ENDED couple stay there and remain inaccessible.
 */
export async function applyPairing(
  tx: Prisma.TransactionClient,
  requesterId: string,
  partnerId: string,
): Promise<{ coupleId: string; partner: { id: string; name: string | null } }> {
  if (requesterId === partnerId) {
    throw new BadRequestException('You cannot pair with yourself');
  }

  const { userAId, userBId } = canonicalPair(requesterId, partnerId);

  const couple = await tx.couple.create({
    data: {
      userAId,
      userBId,
      status: 'ACTIVE',
    },
  });

  await tx.user.update({
    where: { id: requesterId },
    data: {
      partnerId,
      coupleId: couple.id,
      pairingCode: null,
      pairingCodeExpiresAt: null,
    },
  });

  const updatedPartner = await tx.user.update({
    where: { id: partnerId },
    data: {
      partnerId: requesterId,
      coupleId: couple.id,
      pairingCode: null,
      pairingCodeExpiresAt: null,
    },
  });

  await tx.partnerList.updateMany({
    where: {
      ownerId: { in: [requesterId, partnerId] },
      coupleId: null,
    },
    data: { coupleId: couple.id },
  });

  await tx.pairingRequest.deleteMany({
    where: {
      OR: [{ requesterId }, { requesterId: partnerId }],
    },
  });

  return {
    coupleId: couple.id,
    partner: {
      id: updatedPartner.id,
      name: updatedPartner.name,
    },
  };
}

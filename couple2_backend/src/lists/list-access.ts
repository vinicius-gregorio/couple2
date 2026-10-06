import { ListVisibility, Prisma } from '@prisma/client';

/**
 * Every read of PartnerList or ListItem must go through this filter.
 * A private list exists only for its owner. Callers that miss it leak gifts.
 * Future search, export, or home counts have to use this helper too.
 */
export function listAccessWhere(user: {
  id: string;
  coupleId: string | null;
}): Prisma.PartnerListWhereInput {
  if (!user.coupleId) {
    return { id: { in: [] } };
  }
  return {
    coupleId: user.coupleId,
    OR: [{ visibility: ListVisibility.SHARED }, { ownerId: user.id }],
  };
}

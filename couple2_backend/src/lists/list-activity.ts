/**
 * A private list never reaches the couple feed or the partner's lock screen.
 * Shared lists, including a shared GIFT_IDEAS wishlist, record activity.
 */
export function listEmitsActivity(list: {
  visibility?: string | null;
}): boolean {
  return list.visibility !== 'PRIVATE_FROM_PARTNER';
}

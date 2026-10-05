/**
 * Feature #6 (gift ideas / private lists) must never emit an activity event
 * or a push. Those types are not in this build; the guard stays so a later
 * list type cannot leak onto the partner's lock screen by accident.
 */
const PRIVATE_LIST_TYPES = new Set(['GIFT_IDEAS', 'GIFTS', 'GIFT', 'PRIVATE']);

export function listEmitsActivity(type: string): boolean {
  return !PRIVATE_LIST_TYPES.has(type);
}

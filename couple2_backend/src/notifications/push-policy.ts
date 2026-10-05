import { ActivityType } from '@prisma/client';

export type PushCategory =
  | 'lists'
  | 'importantDates'
  | 'dailyQuestion'
  | 'mood'
  | 'nudges'
  | 'datePlans';

export interface PushPreferenceFlags {
  pushEnabled: boolean;
  lists: boolean;
  importantDates: boolean;
  dailyQuestion: boolean;
  mood: boolean;
  nudges: boolean;
  datePlans: boolean;
  quietStartMin: number | null;
  quietEndMin: number | null;
}

export const DEFAULT_PUSH_PREFERENCES: PushPreferenceFlags = {
  pushEnabled: true,
  lists: true,
  importantDates: true,
  dailyQuestion: true,
  mood: true,
  nudges: true,
  datePlans: true,
  quietStartMin: null,
  quietEndMin: null,
};

export function pushCategoryFor(type: ActivityType): PushCategory {
  switch (type) {
    case ActivityType.LIST_CREATED:
    case ActivityType.LIST_ITEM_ADDED:
    case ActivityType.LIST_ITEM_COMPLETED:
      return 'lists';
    case ActivityType.COUPLE_DATE_UPCOMING:
    case ActivityType.COUPLE_UPDATED:
      return 'importantDates';
    case ActivityType.QUESTION_ANSWERED:
    case ActivityType.QUESTION_UNLOCKED:
      return 'dailyQuestion';
    case ActivityType.MOOD_SHARED:
      return 'mood';
    case ActivityType.NUDGE_SENT:
      return 'nudges';
    case ActivityType.DATE_PLAN_PROPOSED:
    case ActivityType.DATE_PLAN_ACCEPTED:
    case ActivityType.DATE_PLAN_DECLINED:
    case ActivityType.DATE_PLAN_COUNTERED:
    case ActivityType.DATE_PLAN_CANCELLED:
    case ActivityType.DATE_PLAN_DONE:
      return 'datePlans';
    default: {
      const exhaustive: never = type;
      return exhaustive;
    }
  }
}

export function categoryEnabled(
  prefs: PushPreferenceFlags,
  category: PushCategory,
): boolean {
  return prefs[category];
}

export interface PushDecisionInput {
  pushEnabled: boolean;
  categoryEnabled: boolean;
  quiet: boolean;
  spamBlocked: boolean;
}

/** Feed is always written. This only decides the push. */
export function shouldDeliverPush(input: PushDecisionInput): boolean {
  return (
    input.pushEnabled &&
    input.categoryEnabled &&
    !input.quiet &&
    !input.spamBlocked
  );
}

/** At most one list push per recipient inside this window. The rest stay in the feed. */
export const LIST_PUSH_WINDOW_MS = 5 * 60 * 1000;

export const LIST_ACTIVITY_TYPES: ActivityType[] = [
  ActivityType.LIST_CREATED,
  ActivityType.LIST_ITEM_ADDED,
  ActivityType.LIST_ITEM_COMPLETED,
];

import { MoodLevel } from '@prisma/client';

export const MOOD_NOTE_MAX = 140;
export const NUDGE_MESSAGE_MAX = 80;
export const NUDGE_HOURLY_LIMIT = 10;
export const NUDGE_WINDOW_MS = 60 * 60 * 1000;
export const NUDGE_COLLAPSE_WINDOW_MS = 10 * 60 * 1000;
/** More than this many nudges in the collapse window share one push line. */
export const NUDGE_COLLAPSE_AFTER = 3;
export const MOOD_STALE_MS = 24 * 60 * 60 * 1000;
export const MOOD_HISTORY_DEFAULT_DAYS = 30;
export const MOOD_HISTORY_MAX_DAYS = 90;
export const MOOD_HISTORY_DAY_MS = 24 * 60 * 60 * 1000;
export const MOOD_ROUTE = '/mood/history';
export const NUDGE_ROUTE = '/nudges';
export const NUDGE_COLLAPSE_KEY = 'nudge';
export const RECEIVED_NUDGES_DEFAULT_LIMIT = 20;

export function pushesForMood(mood: MoodLevel): boolean {
  return mood === MoodLevel.LOW || mood === MoodLevel.BAD;
}

/** A check-in older than 24 hours is stale. Exactly 24 hours is still current. */
export function isMoodStale(createdAt: Date, now: Date): boolean {
  return now.getTime() - createdAt.getTime() > MOOD_STALE_MS;
}

/**
 * Seconds until the oldest nudge in the rolling hour falls out of the window.
 * Always at least 1 so a client can wait and retry.
 */
export function nudgeRetryAfterSeconds(
  oldestCreatedAt: Date,
  now: Date,
): number {
  const remainingMs =
    oldestCreatedAt.getTime() + NUDGE_WINDOW_MS - now.getTime();
  return Math.max(1, Math.ceil(remainingMs / 1000));
}

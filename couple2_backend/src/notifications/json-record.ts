export function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

/** Lock-screen text is public. Item content is stored and pushed truncated. */
export const PUSH_CONTENT_MAX = 80;

export function truncateContent(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length <= PUSH_CONTENT_MAX) return trimmed;
  return `${trimmed.slice(0, PUSH_CONTENT_MAX - 1)}…`;
}

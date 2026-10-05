/**
 * `receiverId` is never a client field. The global pipe rejects unknown
 * properties, so this removes the key before validation. The service always
 * sets the receiver from `user.partnerId`.
 */
export function stripClientReceiverId(body: unknown): void {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return;
  delete (body as Record<string, unknown>).receiverId;
}

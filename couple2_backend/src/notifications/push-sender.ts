export interface PushMessage {
  tokens: string[];
  notification: { title: string; body: string };
  data: { type: string; route: string };
  /** Android collapse key and APNs thread-id / collapse id. One per entity. */
  collapseKey: string;
}

export interface PushSendResult {
  token: string;
  success: boolean;
  errorCode?: string;
}

export interface PushSender {
  send(message: PushMessage): Promise<PushSendResult[]>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

/**
 * FCM error codes that mean the token can never work again.
 * Spec: messaging/registration-token-not-registered and invalid-argument.
 */
export const INVALID_TOKEN_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-argument',
]);

export function isInvalidTokenError(code: string | undefined): boolean {
  return !!code && INVALID_TOKEN_ERROR_CODES.has(code);
}

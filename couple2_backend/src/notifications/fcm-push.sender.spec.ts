import type { BatchResponse } from 'firebase-admin/messaging';
import { FcmPushSender } from './fcm-push.sender';
import { isInvalidTokenError } from './push-sender';

describe('FcmPushSender', () => {
  it('maps multicast failures, including the codes that drop a token', () => {
    expect(
      isInvalidTokenError('messaging/registration-token-not-registered'),
    ).toBe(true);
    expect(isInvalidTokenError('messaging/invalid-argument')).toBe(true);
    expect(isInvalidTokenError('messaging/internal-error')).toBe(false);

    const sender = new FcmPushSender(() =>
      Promise.resolve({
        responses: [
          { success: true },
          {
            success: false,
            error: Object.assign(new Error('gone'), {
              code: 'messaging/registration-token-not-registered',
              toJSON: () => ({}),
            }),
          },
        ],
        successCount: 1,
        failureCount: 1,
      } as BatchResponse),
    );

    return expect(
      sender.send({
        tokens: ['good-token', 'dead-token'],
        notification: { title: 't', body: 'b' },
        data: { type: 'LIST_ITEM_ADDED', route: '/lists/1' },
        collapseKey: 'ListItem:1',
      }),
    ).resolves.toEqual([
      { token: 'good-token', success: true, errorCode: undefined },
      {
        token: 'dead-token',
        success: false,
        errorCode: 'messaging/registration-token-not-registered',
      },
    ]);
  });
});

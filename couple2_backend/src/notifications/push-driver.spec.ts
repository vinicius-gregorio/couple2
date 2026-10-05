import { LogPushSender } from './log-push.sender';
import {
  createPushSender,
  hasFirebaseCredential,
  resolvePushDriver,
} from './push-driver';

describe('push driver', () => {
  const missing = {
    FIREBASE_SERVICE_ACCOUNT: '',
    FIREBASE_SERVICE_ACCOUNT_PATH: '/tmp/couple2-no-such-service-account.json',
  };

  it('defaults to log in development and when credentials are missing', () => {
    expect(hasFirebaseCredential(missing)).toBe(false);
    expect(
      resolvePushDriver({ ...missing, NODE_ENV: 'development' }, false),
    ).toBe('log');
    expect(
      resolvePushDriver({ ...missing, NODE_ENV: 'production' }, false),
    ).toBe('log');
    expect(
      resolvePushDriver(
        { ...missing, NODE_ENV: 'production', PUSH_DRIVER: 'fcm' },
        false,
      ),
    ).toBe('log');
    expect(
      resolvePushDriver({ NODE_ENV: 'development', PUSH_DRIVER: 'fcm' }, true),
    ).toBe('fcm');
    expect(resolvePushDriver({ NODE_ENV: 'production' }, true)).toBe('fcm');
    expect(
      resolvePushDriver({ NODE_ENV: 'production', PUSH_DRIVER: 'log' }, true),
    ).toBe('log');
  });

  it('PUSH_DRIVER=log does not construct the FCM sender', () => {
    expect(createPushSender({ ...missing, PUSH_DRIVER: 'log' })).toBeInstanceOf(
      LogPushSender,
    );
  });
});

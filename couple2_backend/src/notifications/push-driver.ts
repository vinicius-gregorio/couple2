import { existsSync } from 'fs';
import { Logger } from '@nestjs/common';
import { resolve } from 'path';
import { FcmPushSender } from './fcm-push.sender';
import { LogPushSender } from './log-push.sender';
import { PushSender } from './push-sender';

export type PushDriverName = 'log' | 'fcm';

export function hasFirebaseCredential(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  if (env.FIREBASE_SERVICE_ACCOUNT?.trim()) return true;
  const path = resolve(
    env.FIREBASE_SERVICE_ACCOUNT_PATH ?? './serviceAccount.json',
  );
  return existsSync(path);
}

/**
 * `PUSH_DRIVER=log` or missing credentials always log.
 * With credentials, dev still defaults to log. Production defaults to FCM.
 */
export function resolvePushDriver(
  env: NodeJS.ProcessEnv = process.env,
  credentialPresent = hasFirebaseCredential(env),
): PushDriverName {
  const explicit = env.PUSH_DRIVER?.trim().toLowerCase();
  if (explicit === 'log') return 'log';
  if (!credentialPresent) return 'log';
  if (explicit === 'fcm') return 'fcm';
  if ((env.NODE_ENV ?? 'development') !== 'production') return 'log';
  return 'fcm';
}

export function createPushSender(
  env: NodeJS.ProcessEnv = process.env,
): PushSender {
  const driver = resolvePushDriver(env);
  new Logger('PushDriver').log(`Using push driver "${driver}"`);
  return driver === 'fcm' ? new FcmPushSender() : new LogPushSender();
}

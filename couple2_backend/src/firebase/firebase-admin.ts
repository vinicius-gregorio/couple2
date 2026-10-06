import { Logger } from '@nestjs/common';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import * as admin from 'firebase-admin';

const logger = new Logger('FirebaseAdmin');

/**
 * Firebase Admin verifies Firebase ID tokens for `POST /auth/firebase`
 * and sends FCM when `PUSH_DRIVER=fcm`. It is not used for data access.
 * `PUSH_DRIVER=log` (the dev default) never calls this.
 *
 * Local `POST /auth/dev-login` and every Postgres read/write work without a
 * service account. Credentials are resolved only when a real Firebase login
 * is attempted, in this order:
 *   1. FIREBASE_SERVICE_ACCOUNT      — inline service-account JSON (raw or base64)
 *   2. FIREBASE_SERVICE_ACCOUNT_PATH — path to a service-account JSON file
 *   3. ./serviceAccount.json         — default gitignored file in the backend root
 *
 * Idempotent: safe to call many times.
 */
export function ensureFirebase(): void {
  if (admin.apps.length) {
    return;
  }

  const serviceAccount = normalizeServiceAccount(loadServiceAccount());

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const projectId = serviceAccount.projectId ?? serviceAccount.project_id;
  const clientEmail = serviceAccount.clientEmail ?? serviceAccount.client_email;
  logger.log(
    `Firebase Admin initialized project_id=${projectId ?? 'unknown'} client_email=${clientEmail ?? 'unknown'}`,
  );
}

export type FirebaseServiceAccountJson = admin.ServiceAccount & {
  project_id?: string;
  private_key?: string;
  client_email?: string;
};

/**
 * Railway and other env UIs sometimes store the service-account JSON with
 * literal backslash-n sequences in `private_key` instead of real newlines.
 * `credential.cert()` rejects that key. Keys that already contain newlines
 * are left unchanged.
 */
export function normalizeServiceAccount(
  account: FirebaseServiceAccountJson,
): FirebaseServiceAccountJson {
  const next: FirebaseServiceAccountJson = { ...account };
  if (typeof account.privateKey === 'string') {
    next.privateKey = normalizePrivateKey(account.privateKey);
  }
  if (typeof account.private_key === 'string') {
    next.private_key = normalizePrivateKey(account.private_key);
  }
  return next;
}

function normalizePrivateKey(key: string | undefined): string | undefined {
  if (!key || key.includes('\n') || !key.includes('\\n')) {
    return key;
  }
  return key.replace(/\\n/g, '\n');
}

function loadServiceAccount(): FirebaseServiceAccountJson {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (inline) {
    const json = inline.startsWith('{')
      ? inline
      : Buffer.from(inline, 'base64').toString('utf-8');
    return JSON.parse(json) as FirebaseServiceAccountJson;
  }

  const path = resolve(
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ?? './serviceAccount.json',
  );
  if (existsSync(path)) {
    return JSON.parse(
      readFileSync(path, 'utf-8'),
    ) as FirebaseServiceAccountJson;
  }

  throw new Error(
    'Firebase credentials not found. They are required only for POST /auth/firebase. ' +
      'Set FIREBASE_SERVICE_ACCOUNT (inline JSON or base64), or FIREBASE_SERVICE_ACCOUNT_PATH, ' +
      'or place serviceAccount.json in the backend root. Local dev-login does not need them.',
  );
}

import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import * as admin from 'firebase-admin';

/**
 * Centralized Firebase Admin initialization, shared by the Firestore data layer
 * (PrismaService) and the auth token verifier (FirebaseAuthStrategy).
 *
 * Credentials are resolved in this order:
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

  const serviceAccount = loadServiceAccount();

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

export function getFirestore(): FirebaseFirestore.Firestore {
  ensureFirebase();
  return admin.firestore();
}

function loadServiceAccount(): admin.ServiceAccount {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (inline) {
    const json = inline.startsWith('{')
      ? inline
      : Buffer.from(inline, 'base64').toString('utf-8');
    return JSON.parse(json) as admin.ServiceAccount;
  }

  const path = resolve(
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ?? './serviceAccount.json',
  );
  if (existsSync(path)) {
    return JSON.parse(readFileSync(path, 'utf-8')) as admin.ServiceAccount;
  }

  throw new Error(
    'Firebase credentials not found. Set FIREBASE_SERVICE_ACCOUNT (inline JSON ' +
      'or base64), or FIREBASE_SERVICE_ACCOUNT_PATH, or place serviceAccount.json ' +
      'in the backend root.',
  );
}

import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ensureFirebase } from '../../firebase/firebase-admin';

export interface FirebaseUser {
  firebaseUid: string;
  email: string;
  name: string | null;
  picture: string | null;
  provider: string | null;
}

@Injectable()
export class FirebaseAuthStrategy {
  private readonly logger = new Logger(FirebaseAuthStrategy.name);

  async validateIdToken(idToken: string): Promise<FirebaseUser> {
    try {
      // Lazy init so the backend can boot without the service-account key.
      ensureFirebase();
      const decoded = await admin.auth().verifyIdToken(idToken);

      if (!decoded.email) {
        throw new UnauthorizedException('Email not provided by Firebase token');
      }

      return {
        firebaseUid: decoded.uid,
        email: decoded.email,
        name: decoded.name || null,
        picture: decoded.picture || null,
        provider: decoded.firebase?.sign_in_provider || null,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      this.logger.error(formatFirebaseAuthFailure(error, idToken));
      throw new UnauthorizedException('Failed to validate Firebase ID token');
    }
  }
}

/**
 * Server log for a failed `verifyIdToken` or `ensureFirebase` call.
 * The HTTP body stays the generic 401. The token and any PEM are redacted.
 */
export function formatFirebaseAuthFailure(
  error: unknown,
  idToken?: string,
): string {
  const code = readErrorCode(error);
  const message = redactSecrets(readErrorMessage(error), idToken);
  return code
    ? `Firebase ID token validation failed code=${code} message=${message}`
    : `Firebase ID token validation failed message=${message}`;
}

function readErrorCode(error: unknown): string | undefined {
  if (!error || typeof error !== 'object') {
    return undefined;
  }
  const record = error as {
    code?: unknown;
    errorInfo?: { code?: unknown };
  };
  const code = record.code ?? record.errorInfo?.code;
  return typeof code === 'string' && code.length > 0 ? code : undefined;
}

function readErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === 'string' && message.length > 0) {
      return message;
    }
  }
  return 'Unknown error';
}

function redactSecrets(message: string, idToken?: string): string {
  let redacted = message.replace(
    /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
    '[redacted-private-key]',
  );
  if (idToken) {
    redacted = redacted.split(idToken).join('[redacted-id-token]');
  }
  return redacted;
}

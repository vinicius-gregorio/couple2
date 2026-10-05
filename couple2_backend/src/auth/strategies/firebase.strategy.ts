import { Injectable, UnauthorizedException } from '@nestjs/common';
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
      throw new UnauthorizedException('Failed to validate Firebase ID token');
    }
  }
}

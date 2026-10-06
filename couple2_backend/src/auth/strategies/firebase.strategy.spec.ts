import { Logger, UnauthorizedException } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ensureFirebase } from '../../firebase/firebase-admin';
import {
  FirebaseAuthStrategy,
  formatFirebaseAuthFailure,
} from './firebase.strategy';

jest.mock('../../firebase/firebase-admin', () => ({
  ensureFirebase: jest.fn(),
}));

jest.mock('firebase-admin', () => ({
  auth: jest.fn(),
}));

describe('FirebaseAuthStrategy.validateIdToken', () => {
  const errorSpy = jest
    .spyOn(Logger.prototype, 'error')
    .mockImplementation(() => undefined);
  const ensure = ensureFirebase as unknown as jest.Mock;
  const auth = admin.auth as unknown as jest.Mock;
  const idToken = 'header.payload.signature';

  beforeEach(() => {
    errorSpy.mockClear();
    ensure.mockReset();
    ensure.mockImplementation(() => undefined);
    auth.mockReset();
  });

  afterAll(() => {
    errorSpy.mockRestore();
  });

  it('logs the Firebase error code and message, then throws a generic 401', async () => {
    auth.mockReturnValue({
      verifyIdToken: jest.fn().mockRejectedValue(
        Object.assign(new Error('Firebase ID token has expired'), {
          code: 'auth/id-token-expired',
        }),
      ),
    });

    const strategy = new FirebaseAuthStrategy();

    await expect(strategy.validateIdToken(idToken)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    await expect(strategy.validateIdToken(idToken)).rejects.toThrow(
      'Failed to validate Firebase ID token',
    );

    const logged = errorSpy.mock.calls
      .map((call) => String(call[0]))
      .join('\n');
    expect(logged).toContain('code=auth/id-token-expired');
    expect(logged).toContain('Firebase ID token has expired');
    expect(logged).not.toContain(idToken);
  });

  it('logs ensureFirebase failures without changing the client message', async () => {
    ensure.mockImplementation(() => {
      throw Object.assign(new Error('Firebase credentials not found'), {
        code: 'app/invalid-credential',
      });
    });

    await expect(
      new FirebaseAuthStrategy().validateIdToken(idToken),
    ).rejects.toThrow('Failed to validate Firebase ID token');

    const logged = String(errorSpy.mock.calls[0][0]);
    expect(logged).toContain('code=app/invalid-credential');
    expect(logged).toContain('Firebase credentials not found');
    expect(logged).not.toContain(idToken);
  });

  it('keeps the email-missing 401 and does not wrap it', async () => {
    auth.mockReturnValue({
      verifyIdToken: jest.fn().mockResolvedValue({ uid: 'uid-1' }),
    });

    await expect(
      new FirebaseAuthStrategy().validateIdToken(idToken),
    ).rejects.toThrow('Email not provided by Firebase token');
    expect(errorSpy).not.toHaveBeenCalled();
  });
});

describe('formatFirebaseAuthFailure', () => {
  it('redacts the ID token and a private key from the logged message', () => {
    const idToken = 'eyJhbGciOiJub25lIn0.payload.sig';
    const error = new Error(
      `bad ${idToken} -----BEGIN PRIVATE KEY-----\nSECRET\n-----END PRIVATE KEY-----`,
    );

    const logged = formatFirebaseAuthFailure(error, idToken);

    expect(logged).not.toContain(idToken);
    expect(logged).not.toContain('SECRET');
    expect(logged).toContain('[redacted-id-token]');
    expect(logged).toContain('[redacted-private-key]');
  });
});

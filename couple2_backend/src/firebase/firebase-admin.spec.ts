import { Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ensureFirebase, normalizeServiceAccount } from './firebase-admin';

jest.mock('firebase-admin', () => {
  const apps: object[] = [];
  return {
    apps,
    credential: {
      cert: jest.fn((value: unknown) => value),
    },
    initializeApp: jest.fn(() => {
      const app = { name: '[DEFAULT]' };
      apps.push(app);
      return app;
    }),
  };
});

const cert = admin.credential.cert as unknown as jest.Mock;
const PRIVATE_KEY_LITERAL =
  '-----BEGIN PRIVATE KEY-----\\nLINE\\n-----END PRIVATE KEY-----\\n';

describe('normalizeServiceAccount', () => {
  it('rewrites a private_key that has literal \\n and no real newlines', () => {
    const normalized = normalizeServiceAccount({
      project_id: 'couple42-f87b6',
      client_email: 'sdk@couple42-f87b6.iam.gserviceaccount.com',
      private_key: PRIVATE_KEY_LITERAL,
    });

    expect(normalized.private_key).toBe(
      '-----BEGIN PRIVATE KEY-----\nLINE\n-----END PRIVATE KEY-----\n',
    );
    expect(normalized.private_key).not.toContain('\\n');
  });

  it('leaves a private_key that already contains real newlines unchanged', () => {
    const privateKey =
      '-----BEGIN PRIVATE KEY-----\nALREADY\n-----END PRIVATE KEY-----\n';

    expect(
      normalizeServiceAccount({ private_key: privateKey }).private_key,
    ).toBe(privateKey);
  });
});

describe('ensureFirebase', () => {
  const logSpy = jest
    .spyOn(Logger.prototype, 'log')
    .mockImplementation(() => undefined);

  beforeEach(() => {
    (admin.apps as object[]).length = 0;
    cert.mockClear();
    (admin.initializeApp as unknown as jest.Mock).mockClear();
    logSpy.mockClear();
    delete process.env.FIREBASE_SERVICE_ACCOUNT;
    delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  });

  afterAll(() => {
    logSpy.mockRestore();
  });

  it('passes the normalized key to cert and logs only project_id and client_email', () => {
    const account = {
      type: 'service_account',
      project_id: 'couple42-f87b6',
      client_email: 'sdk@couple42-f87b6.iam.gserviceaccount.com',
      private_key: PRIVATE_KEY_LITERAL,
    };
    process.env.FIREBASE_SERVICE_ACCOUNT = Buffer.from(
      JSON.stringify(account),
    ).toString('base64');

    ensureFirebase();

    const passed = cert.mock.calls[0][0] as { private_key: string };
    expect(passed.private_key).toContain('\n');
    expect(passed.private_key).not.toContain('\\n');

    const logged = logSpy.mock.calls.map((call) => String(call[0])).join('\n');
    expect(logged).toContain('project_id=couple42-f87b6');
    expect(logged).toContain(
      'client_email=sdk@couple42-f87b6.iam.gserviceaccount.com',
    );
    expect(logged).not.toContain('BEGIN PRIVATE KEY');
    expect(logged).not.toContain('LINE');
    expect(logged).not.toContain(process.env.FIREBASE_SERVICE_ACCOUNT);
  });
});

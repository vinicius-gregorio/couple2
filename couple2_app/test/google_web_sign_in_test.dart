import 'package:couple2_app/modules/auth/data/google_web_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web calls redirect and skips popup when redirect succeeds', () async {
    final calls = <String>[];

    await signInWithGoogleOnWeb(
      signInWithRedirect: () async => calls.add('redirect'),
      signInWithPopup: () async => calls.add('popup'),
      hasCurrentUser: () => true,
    );

    expect(calls, ['redirect']);
  });

  test('web uses popup only after redirect throws', () async {
    final calls = <String>[];

    await signInWithGoogleOnWeb(
      signInWithRedirect: () async {
        calls.add('redirect');
        throw FirebaseAuthException(
          code: 'operation-not-supported-in-this-environment',
          message: 'Redirect is not available.',
        );
      },
      signInWithPopup: () async => calls.add('popup'),
      hasCurrentUser: () => false,
    );

    expect(calls, ['redirect', 'popup']);
  });

  test('a started redirect waits for getRedirectResult', () async {
    var popupCalled = false;

    await expectLater(
      signInWithGoogleOnWeb(
        signInWithRedirect: () async {},
        signInWithPopup: () async => popupCalled = true,
        hasCurrentUser: () => false,
      ),
      throwsA(isA<GoogleRedirectInProgress>()),
    );
    expect(popupCalled, isFalse);
  });

  test('popup failure keeps the Firebase error code', () async {
    await expectLater(
      signInWithGoogleOnWeb(
        signInWithRedirect: () async => throw Exception('redirect down'),
        signInWithPopup: () async {
          throw FirebaseAuthException(
            code: 'popup-blocked',
            message: 'Popup blocked',
          );
        },
        hasCurrentUser: () => false,
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'popup-blocked',
        ),
      ),
    );
  });

  test('redirect Firebase code is kept when popup has none', () async {
    await expectLater(
      signInWithGoogleOnWeb(
        signInWithRedirect: () async {
          throw FirebaseAuthException(
            code: 'unauthorized-domain',
            message: 'Domain is not authorized.',
          );
        },
        signInWithPopup: () async => throw Exception('popup failed'),
        hasCurrentUser: () => false,
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'unauthorized-domain',
        ),
      ),
    );
  });

  test('redirect result with a user exchanges the ID token', () async {
    var logins = 0;

    final completed = await completeGoogleRedirect(
      hasRedirectUser: () async => true,
      completeLogin: () async => logins++,
    );

    expect(completed, isTrue);
    expect(logins, 1);
  });

  test('redirect result without a user does not exchange a token', () async {
    var logins = 0;

    final completed = await completeGoogleRedirect(
      hasRedirectUser: () async => false,
      completeLogin: () async => logins++,
    );

    expect(completed, isFalse);
    expect(logins, 0);
  });

  test('redirect bootstrap reports login errors instead of dropping them', () async {
    Object? reported;

    await runGoogleRedirectBootstrap(
      hasRedirectUser: () async => true,
      completeLogin: () async {
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: 'offline',
        );
      },
      onError: (error) => reported = error,
    );

    expect(
      reported,
      isA<FirebaseAuthException>().having(
        (error) => error.code,
        'code',
        'network-request-failed',
      ),
    );
  });

  test('redirect bootstrap skips login when nobody returned', () async {
    var logins = 0;
    var reported = false;

    await runGoogleRedirectBootstrap(
      hasRedirectUser: () async => false,
      completeLogin: () async => logins++,
      onError: (_) => reported = true,
    );

    expect(logins, 0);
    expect(reported, isFalse);
  });
}

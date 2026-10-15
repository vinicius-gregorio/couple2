import 'package:couple2_app/modules/auth/data/google_web_sign_in.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelled popups say login cancelado', () {
    for (final code in ['popup-closed-by-user', 'cancelled-popup-request']) {
      final message = formatAuthError(
        FirebaseAuthException(
          code: code,
          message: 'The popup has been closed by the user before finalizing.',
        ),
      );
      expect(message, 'Login cancelado');
      expect(message.toLowerCase(), isNot(contains('popup')));
    }
  });

  test('network and disabled provider are portuguese', () {
    expect(
      formatAuthError(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error (such as timeout) has occurred.',
        ),
      ),
      'Sem conexão. Verifique a internet e tente de novo.',
    );
    expect(
      formatAuthError(
        FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'The identity provider configuration is not found.',
        ),
      ),
      'Este tipo de login não está disponível.',
    );
  });

  test('a redirect failure is not called cancelado', () {
    final message = formatAuthError(
      FirebaseAuthException(
        code: 'network-request-failed',
        message: 'createAuthUri failed',
      ),
    );

    expect(message, 'Sem conexão. Verifique a internet e tente de novo.');
    expect(message, isNot('Login cancelado'));
  });

  test('a cancelled Google redirect clears the spinner', () {
    const spinning = AuthState(googleLoading: true);
    final next = applyGoogleRedirectResume(
      spinning,
      GoogleRedirectResume.cancelled,
    );

    expect(next.googleLoading, isFalse);
    expect(next.errorMessage, 'Login cancelado');
    expect(formatAuthError(const CancelledGoogleRedirect()), next.errorMessage);
  });

  test('other auth failures use a portuguese fallback', () {
    final firebase = formatAuthError(
      FirebaseAuthException(code: 'popup-blocked', message: 'Popup blocked'),
    );
    final generic = formatAuthError(Exception('Something went wrong'));

    expect(firebase, 'Não foi possível entrar. Tente de novo.');
    expect(generic, firebase);
    expect(firebase, isNot(contains('Popup')));
    expect(firebase, isNot(contains('popup-blocked')));
    expect(generic, isNot(contains('Something')));
  });
}

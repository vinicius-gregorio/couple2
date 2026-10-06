import 'package:couple2_app/modules/auth/ui/pages/auth/auth_page.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_viewmodel.dart';
import 'package:couple2_app/modules/auth/ui/widgets/google_sign_in_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoadingAuth extends AuthViewModel {
  @override
  AuthState build() => const AuthState(isLoading: true);
}

class _ErrorAuth extends AuthViewModel {
  @override
  AuthState build() => const AuthState(
    errorMessage: 'configuration-not-found: Firebase auth is not configured.',
  );
}

void main() {
  test('formatAuthError includes the Firebase error code', () {
    final error = FirebaseAuthException(
      code: 'configuration-not-found',
      message: 'Firebase auth is not configured.',
    );

    expect(
      formatAuthError(error),
      'configuration-not-found: Firebase auth is not configured.',
    );
  });

  test('copyWith can clear a previous error', () {
    const state = AuthState(errorMessage: 'popup-blocked: blocked');

    final next = state.copyWith(isLoading: true, errorMessage: null);

    expect(next.isLoading, isTrue);
    expect(next.errorMessage, isNull);
  });

  testWidgets('Google button shows a spinner and ignores taps while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('Google button uses the bundled logo when idle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GoogleSignInButton(onPressed: _noop)),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsNothing);
  });

  testWidgets('login page shows the auth error code', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(_ErrorAuth.new)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );

    expect(
      find.text('configuration-not-found: Firebase auth is not configured.'),
      findsOneWidget,
    );
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsNothing);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('login page keeps the Google button in a loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(_LoadingAuth.new)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );

    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}

void _noop() {}

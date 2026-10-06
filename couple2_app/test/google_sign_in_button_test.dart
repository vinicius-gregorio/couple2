import 'dart:async';

import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/modules/auth/data/auth_providers.dart';
import 'package:couple2_app/modules/auth/data/auth_repository.dart';
import 'package:couple2_app/modules/auth/data/google_web_sign_in.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_page.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_viewmodel.dart';
import 'package:couple2_app/modules/auth/ui/widgets/google_sign_in_button.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
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

  testWidgets('Google button is a full-width opaque target', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GoogleSignInButton(onPressed: _noop)),
      ),
    );

    final detector = tester.widget<GestureDetector>(
      find.descendant(
        of: find.byType(GoogleSignInButton),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(detector.behavior, HitTestBehavior.opaque);

    final size = tester.getSize(find.byType(GoogleSignInButton));
    expect(size.height, greaterThanOrEqualTo(GoogleSignInButton.minHeight));
    expect(size.width, tester.getSize(find.byType(Scaffold)).width);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(GoogleSignInButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, GoogleSignInButton.backgroundColor);
    final border = material.shape! as RoundedRectangleBorder;
    expect(border.side.color, GoogleSignInButton.borderColor);
    expect(border.side.width, 2);
    expect(
      GoogleSignInButton.backgroundColor.computeLuminance(),
      lessThan(0.15),
    );
    expect(GoogleSignInButton.foregroundColor, const Color(0xFFFFFFFF));
    expect(
      GoogleSignInButton.borderColor.computeLuminance(),
      lessThan(GoogleSignInButton.backgroundColor.computeLuminance()),
    );
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('sets loading before Google sign-in finishes', (tester) async {
    final repo = _ScriptedAuthRepository();
    final pending = Completer<User>();
    bool? loadingWhenCalled;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuthPage)),
    );
    repo.onGoogle = () {
      loadingWhenCalled = container.read(authViewModelProvider).isLoading;
      return pending.future;
    };

    await tester.tap(find.text('Entrar com Google'));
    expect(loadingWhenCalled, isTrue);
    expect(container.read(authViewModelProvider).isLoading, isTrue);
    expect(pending.isCompleted, isFalse);
    expect(repo.googleCalls, 1);

    await tester.tap(find.text('Entrar com Google'));
    expect(repo.googleCalls, 1);

    await tester.pump();
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.textContaining('popup-blocked'), findsNothing);
  });

  testWidgets('failed Google sign-in shows the code inline and in a SnackBar', (
    tester,
  ) async {
    const message = 'popup-blocked: Popup blocked';
    final repo = _ScriptedAuthRepository(
      onGoogle: () async {
        throw FirebaseAuthException(
          code: 'popup-blocked',
          message: 'Popup blocked',
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(message), findsWidgets);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsNothing);
  });

  testWidgets('a redirect in progress keeps the spinner and shows no error', (
    tester,
  ) async {
    final repo = _ScriptedAuthRepository(
      onGoogle: () async {
        throw const GoogleRedirectInProgress();
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a startup redirect error is visible', (tester) async {
    PendingGoogleAuthError.report(
      FirebaseAuthException(
        code: 'web-storage-unsupported',
        message: 'Storage is blocked.',
      ),
    );
    addTearDown(PendingGoogleAuthError.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_ScriptedAuthRepository()),
        ],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('web-storage-unsupported: Storage is blocked.'),
      findsWidgets,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

void _noop() {}

class _ScriptedAuthRepository implements IAuthRepository {
  _ScriptedAuthRepository({this.onGoogle});

  Future<User> Function()? onGoogle;
  final Completer<User> _hanging = Completer<User>();
  int googleCalls = 0;

  @override
  final AuthStateNotifier authStateNotifier = AuthStateNotifier();

  @override
  Future<bool> isLoggedIn() async => false;

  @override
  Future<User> signInWithGoogle() {
    googleCalls++;
    final action = onGoogle;
    if (action == null) return _hanging.future;
    return action();
  }

  @override
  Future<User> signInWithApple() => _hanging.future;

  @override
  Future<void> logOut() async {}

  @override
  void publishLoggedIn(bool loggedIn) => authStateNotifier.publish(loggedIn);
}

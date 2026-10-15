import 'dart:async';

import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/auth/data/auth_providers.dart';
import 'package:couple2_app/modules/auth/data/auth_repository.dart';
import 'package:couple2_app/modules/auth/data/google_web_sign_in.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_page.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_viewmodel.dart';
import 'package:couple2_app/modules/auth/ui/widgets/apple_sign_in_button.dart';
import 'package:couple2_app/modules/auth/ui/widgets/google_sign_in_button.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoadingAuth extends AuthViewModel {
  @override
  AuthState build() => const AuthState(googleLoading: true);
}

class _AppleLoadingAuth extends AuthViewModel {
  @override
  AuthState build() => const AuthState(appleLoading: true);
}

class _ErrorAuth extends AuthViewModel {
  @override
  AuthState build() =>
      const AuthState(errorMessage: 'Não foi possível entrar. Tente de novo.');
}

void main() {
  test('copyWith can clear a previous error', () {
    const state = AuthState(
      errorMessage: 'Não foi possível entrar. Tente de novo.',
    );

    final next = state.copyWith(googleLoading: true, errorMessage: null);

    expect(next.googleLoading, isTrue);
    expect(next.appleLoading, isFalse);
    expect(next.errorMessage, isNull);
  });

  testWidgets('Google button shows a spinner and ignores taps while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(isLoading: true, onPressed: () => taps++),
        ),
      ),
    );

    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);

    await tester.tap(find.byType(GoogleSignInButton));
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
      find.text('Não foi possível entrar. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Entrar com Apple'), findsNothing);
    expect(find.byType(AppleSignInButton), findsNothing);
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
    expect(find.byType(AppleSignInButton), findsNothing);
  });

  testWidgets('Google button is a full-width opaque target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const Scaffold(body: GoogleSignInButton(onPressed: _noop)),
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
    final scheme = lightColorScheme;
    expect(material.color, scheme.primary);
    final border = material.shape! as RoundedRectangleBorder;
    expect(border.side.width, 2);
    expect(scheme.primary.computeLuminance(), lessThan(0.15));
    expect(scheme.onPrimary, const Color(0xFFFFFFFF));
    expect(
      border.side.color.computeLuminance(),
      lessThan(scheme.primary.computeLuminance()),
    );
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('login hides Apple and keeps Google independent of it', (
    tester,
  ) async {
    final repo = _ScriptedAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authViewModelProvider.overrideWith(_AppleLoadingAuth.new),
        ],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pump();

    expect(kAppleSignInEnabled, isFalse);
    expect(find.byType(AppleSignInButton), findsNothing);
    expect(find.text('Entrar com Apple'), findsNothing);
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsNothing);

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();

    expect(repo.googleCalls, 1);
    expect(repo.appleCalls, 0);
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
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
      loadingWhenCalled = container.read(authViewModelProvider).googleLoading;
      return pending.future;
    };

    await tester.tap(find.byType(GoogleSignInButton));
    expect(loadingWhenCalled, isTrue);
    expect(container.read(authViewModelProvider).googleLoading, isTrue);
    expect(container.read(authViewModelProvider).appleLoading, isFalse);
    expect(pending.isCompleted, isFalse);
    expect(repo.googleCalls, 1);

    await tester.tap(find.byType(GoogleSignInButton));
    expect(repo.googleCalls, 1);

    await tester.pump();
    expect(find.byKey(GoogleSignInButton.loadingIndicatorKey), findsOneWidget);
    expect(find.textContaining('popup-blocked'), findsNothing);
  });

  testWidgets('failed Google sign-in shows Portuguese and hides English', (
    tester,
  ) async {
    const message = 'Não foi possível entrar. Tente de novo.';
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

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(message), findsWidgets);
    expect(find.textContaining('Popup blocked'), findsNothing);
    expect(find.textContaining('popup-blocked'), findsNothing);
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

    await tester.tap(find.byType(GoogleSignInButton));
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

    expect(find.text('Não foi possível entrar. Tente de novo.'), findsWidgets);
    expect(find.textContaining('Storage is blocked'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

void _noop() {}

class _ScriptedAuthRepository implements IAuthRepository {
  _ScriptedAuthRepository({this.onGoogle});

  Future<User> Function()? onGoogle;
  Future<User> Function()? onApple;
  final Completer<User> _hanging = Completer<User>();
  int googleCalls = 0;
  int appleCalls = 0;

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
  Future<User> signInWithApple() {
    appleCalls++;
    final action = onApple;
    if (action == null) return _hanging.future;
    return action();
  }

  @override
  Future<void> logOut() async {}

  @override
  void publishLoggedIn(bool loggedIn) => authStateNotifier.publish(loggedIn);
}

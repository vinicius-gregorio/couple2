import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/core.dart';
import '../../../data/auth_providers.dart';
import '../../../data/auth_repository.dart';
import '../../../data/google_web_sign_in.dart';

/// Provider do ViewModel de autenticação
final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

const _unset = _Unset();

class _Unset {
  const _Unset();
}

/// User-visible auth failure. Always includes the Firebase error code.
String formatAuthError(Object error) {
  if (error is firebase_auth.FirebaseAuthException) {
    final code = error.code.trim();
    final message = error.message?.trim();
    if (code.isEmpty) {
      return message == null || message.isEmpty ? error.toString() : message;
    }
    if (message == null || message.isEmpty) return code;
    return '$code: $message';
  }
  return error.toString();
}

/// Estados possíveis da autenticação
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final User? currentUser;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.currentUser,
  });

  AuthState copyWith({
    bool? isLoading,
    Object? errorMessage = _unset,
    bool? isAuthenticated,
    Object? currentUser = _unset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: identical(currentUser, _unset)
          ? this.currentUser
          : currentUser as User?,
    );
  }
}

/// ViewModel para gerenciar o estado de autenticação
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkAuthStatus();
    return const AuthState();
  }

  IAuthRepository get _authRepository => ref.read(authRepositoryProvider);

  /// Verifica o status de autenticação ao inicializar
  Future<void> _checkAuthStatus() async {
    final pendingRedirectError = PendingGoogleAuthError.take();
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      // A tap can fail before this read returns. Keep that error.
      final startupError = pendingRedirectError == null
          ? null
          : formatAuthError(pendingRedirectError);
      state = state.copyWith(
        isAuthenticated: isLoggedIn,
        errorMessage: state.errorMessage ?? startupError,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            state.errorMessage ?? formatAuthError(pendingRedirectError ?? e),
      );
    }
  }

  /// Realiza o login com Google (via Firebase)
  Future<User?> signInWithGoogle() {
    return _runSignIn(_authRepository.signInWithGoogle);
  }

  /// Realiza o login com Apple (via Firebase)
  Future<User?> signInWithApple() {
    return _runSignIn(_authRepository.signInWithApple);
  }

  /// Sets loading before any await so a tap paints a spinner immediately.
  /// A second call while loading is ignored.
  Future<User?> _runSignIn(Future<User> Function() signIn) {
    if (state.isLoading) return Future<User?>.value();
    state = state.copyWith(isLoading: true, errorMessage: null);
    return _finishSignIn(signIn);
  }

  Future<User?> _finishSignIn(Future<User> Function() signIn) async {
    try {
      final user = await signIn();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentUser: user,
        errorMessage: null,
      );
      return user;
    } on GoogleRedirectInProgress {
      // The browser is navigating to Google. Keep the spinner; the session
      // is completed by getRedirectResult on the next load.
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthError(e),
      );
      return null;
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.logOut();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        currentUser: null,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthError(e),
      );
    }
  }

  /// Limpa a mensagem de erro
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

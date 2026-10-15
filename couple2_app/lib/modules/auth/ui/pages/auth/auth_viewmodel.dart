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

/// User-visible auth failure in PT-BR. Firebase's English text stays off screen.
String formatAuthError(Object error) {
  if (error is firebase_auth.FirebaseAuthException) {
    switch (error.code.trim()) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Login cancelado';
      case 'network-request-failed':
        return 'Sem conexão. Verifique a internet e tente de novo.';
      case 'operation-not-allowed':
        return 'Este tipo de login não está disponível.';
      default:
        return 'Não foi possível entrar. Tente de novo.';
    }
  }
  return 'Não foi possível entrar. Tente de novo.';
}

/// Estados possíveis da autenticação
class AuthState {
  final bool googleLoading;
  final bool appleLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final User? currentUser;

  const AuthState({
    this.googleLoading = false,
    this.appleLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.currentUser,
  });

  AuthState copyWith({
    bool? googleLoading,
    bool? appleLoading,
    Object? errorMessage = _unset,
    bool? isAuthenticated,
    Object? currentUser = _unset,
  }) {
    return AuthState(
      googleLoading: googleLoading ?? this.googleLoading,
      appleLoading: appleLoading ?? this.appleLoading,
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
    if (state.googleLoading) return Future<User?>.value();
    state = state.copyWith(googleLoading: true, errorMessage: null);
    return _finishSignIn(
      _authRepository.signInWithGoogle,
      () => state.copyWith(googleLoading: false),
    );
  }

  /// Realiza o login com Apple (via Firebase). The login screen hides this
  /// until the Apple provider is enabled.
  Future<User?> signInWithApple() {
    if (state.appleLoading) return Future<User?>.value();
    state = state.copyWith(appleLoading: true, errorMessage: null);
    return _finishSignIn(
      _authRepository.signInWithApple,
      () => state.copyWith(appleLoading: false),
    );
  }

  /// Sets that provider's spinner before any await. The other provider stays
  /// tappable. A second tap on the same provider is ignored.
  Future<User?> _finishSignIn(
    Future<User> Function() signIn,
    AuthState Function() settle,
  ) async {
    try {
      final user = await signIn();
      state = settle().copyWith(
        isAuthenticated: true,
        currentUser: user,
        errorMessage: null,
      );
      return user;
    } on GoogleRedirectInProgress {
      // The browser is navigating to Google. Keep this provider's spinner;
      // the session is completed by getRedirectResult on the next load.
      return null;
    } catch (e) {
      state = settle().copyWith(errorMessage: formatAuthError(e));
      return null;
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    state = state.copyWith(errorMessage: null);

    try {
      await _authRepository.logOut();
      state = state.copyWith(
        googleLoading: false,
        appleLoading: false,
        isAuthenticated: false,
        currentUser: null,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: formatAuthError(e));
    }
  }

  /// Limpa a mensagem de erro
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/core.dart';
import '../../../data/auth_providers.dart';
import '../../../data/auth_repository.dart';

/// Provider do ViewModel de autenticação
final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

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
    String? errorMessage,
    bool? isAuthenticated,
    User? currentUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser ?? this.currentUser,
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
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      state = state.copyWith(isAuthenticated: isLoggedIn);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
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

  Future<User?> _runSignIn(Future<User> Function() signIn) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await signIn();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentUser: user,
        errorMessage: null,
      );
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Limpa a mensagem de erro
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

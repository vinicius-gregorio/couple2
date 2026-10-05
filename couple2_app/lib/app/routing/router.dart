import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modules/auth/data/auth_providers.dart';
import '../../modules/auth/data/auth_repository.dart';
import '../../modules/auth/routing/routes.dart';
import '../../modules/auth/routing/routing.dart';
import '../../modules/couple/routing/routing.dart';
import '../../modules/lists/routing/routing.dart';
import '../ui/pages/home/home_page.dart';
import 'routes.dart';

/// Provider do GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: APPRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) => _redirect(context, state, authRepository),
    refreshListenable: AuthNotifier(authRepository),
    routes: [
      GoRoute(
        path: APPRoutes.home,
        builder: (context, state) {
          return const HomePage();
        },
      ),
      ...authRoutes,
      ...listsRoutes,
      ...coupleRoutes,
    ],
  );
});

/// Lógica de redirecionamento baseada no estado de autenticação
Future<String?> _redirect(
  BuildContext context,
  GoRouterState state,
  IAuthRepository authRepository,
) async {
  final isLoggedIn = await authRepository.isLoggedIn();
  final isLoggingIn = state.matchedLocation.startsWith('/auth');

  // Se o usuário não está logado, redireciona para login
  if (!isLoggedIn && !isLoggingIn) {
    return AuthRoutes.login;
  }

  // Se o usuário está logado mas ainda está na página de login,
  // redireciona para home
  if (isLoggedIn && isLoggingIn) {
    return APPRoutes.home;
  }

  // Não há necessidade de redirecionar
  return null;
}

/// Notificador para atualizar o GoRouter quando o estado de autenticação mudar
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(IAuthRepository authRepository) {
    // Escuta mudanças no estado de autenticação
    authRepository.authStateNotifier.addListener(notifyListeners);
  }
}

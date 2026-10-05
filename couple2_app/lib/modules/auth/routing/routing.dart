import 'package:go_router/go_router.dart';

import '../ui/pages/auth/auth_page.dart';
import 'routes.dart';

/// Rotas do módulo de autenticação
final authRoutes = [
  GoRoute(
    path: AuthRoutes.login,
    builder: (context, state) {
      return const AuthPage();
    },
  ),
];

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modules/auth/data/auth_providers.dart';
import '../../modules/auth/data/auth_repository.dart';
import '../../modules/auth/routing/routing.dart';
import '../../modules/couple/routing/routing.dart';
import '../../modules/daily_question/routing/routing.dart';
import '../../modules/feed/routing/routing.dart';
import '../../modules/lists/routing/routing.dart';
import '../../modules/date_plans/routing/routing.dart';
import '../../modules/mood/routing/routing.dart';
import '../../modules/notifications/routing/routing.dart';
import '../ui/pages/home/home_page.dart';
import 'auth_redirect.dart';
import 'routes.dart';

/// Reads the stored session once, then mirrors login and logout.
///
/// GoRouter must be created once. This listenable asks it to re-run [redirect]
/// without rebuilding the router (which would reset the URL to `/`).
class AuthGate extends ChangeNotifier {
  AuthGate(this._repo) {
    _repo.authStateNotifier.addListener(_onRepo);
    _restore();
  }

  final IAuthRepository _repo;

  /// Null until the first read of the stored session finishes.
  bool? loggedIn;

  /// Deep link to reopen after the user signs in.
  String? restoreLocation;

  int _generation = 0;

  Future<void> _restore() async {
    final generation = ++_generation;
    final value = await _repo.isLoggedIn();
    if (generation != _generation) return;
    _repo.publishLoggedIn(value);
  }

  void _onRepo() {
    _generation++;
    loggedIn = _repo.authStateNotifier.value;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.authStateNotifier.removeListener(_onRepo);
    super.dispose();
  }
}

final authGateProvider = Provider<AuthGate>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final gate = AuthGate(repo);
  ref.onDispose(gate.dispose);
  return gate;
});

/// Provider do GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final gate = ref.watch(authGateProvider);

  final router = GoRouter(
    initialLocation: APPRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: gate,
    redirect: (context, state) {
      if (gate.loggedIn == false) {
        final remember = locationToRestore(state.uri.toString());
        if (remember != null) gate.restoreLocation = remember;
      }
      final target = resolveAuthRedirect(
        loggedIn: gate.loggedIn,
        matchedLocation: state.matchedLocation,
        restoreLocation: gate.restoreLocation,
      );
      if (gate.loggedIn == true &&
          target != null &&
          target == gate.restoreLocation) {
        gate.restoreLocation = null;
      }
      return target;
    },
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
      ...feedRoutes,
      ...notificationRoutes,
      ...dailyQuestionRoutes,
      ...moodRoutes,
      ...datePlanRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../core/core.dart';
import '../modules/auth/data/auth_providers.dart';
import 'session.dart';

/// Loads `GET /auth/me` on boot, when auth changes, and when [refresh] runs
/// (app resume and after pairing). Replaces the static SharedPreferences user,
/// which kept a stale `partnerId`.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final auth = ref.read(authRepositoryProvider);
    void onAuthChanged() {
      Future<void>.microtask(refresh);
    }

    auth.authStateNotifier.addListener(onAuthChanged);
    ref.onDispose(() => auth.authStateNotifier.removeListener(onAuthChanged));
    return _load();
  }

  /// Call after pairing (P0) and on app resume so Home picks up the couple
  /// without a logout.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  Future<Session?> _load() async {
    final auth = ref.read(authRepositoryProvider);
    if (!await auth.isLoggedIn()) return null;

    final response = await GetIt.I<ICPLHttpClient>().get<Map<String, dynamic>>(
      '/auth/me',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Resposta inválida de /auth/me');
    }
    return Session.fromMe(data);
  }
}

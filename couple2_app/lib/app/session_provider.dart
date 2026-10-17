import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../core/core.dart';
import '../modules/auth/data/auth_providers.dart';
import 'provider_load.dart';
import 'session.dart';

/// Loads `GET /auth/me` on boot, when auth changes, and when [refresh] runs
/// (app resume and after pairing). Replaces the static SharedPreferences user,
/// which kept a stale `partnerId`.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
  retry: noProviderRetry,
);

class SessionNotifier extends AsyncNotifier<Session?> {
  Future<Session?>? _loadFlight;

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
  /// without a logout. Overlapping callers share one `/auth/me`.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (!ref.mounted) return;
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  Future<Session?> _load() {
    return shareInFlight(
      current: _loadFlight,
      read: () => _loadFlight,
      store: (flight) => _loadFlight = flight,
      start: _loadOnce,
    );
  }

  Future<Session?> _loadOnce() async {
    final auth = ref.read(authRepositoryProvider);
    if (!await auth.isLoggedIn()) return null;

    final response = await loadOrTimeout(
      GetIt.I<ICPLHttpClient>().get<Map<String, dynamic>>('/auth/me'),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Resposta inválida de /auth/me');
    }
    return Session.fromMe(data);
  }
}

/// Waits until the session read finishes.
///
/// Watching only `asData` treats "still loading" as "no couple" and a card
/// then paints an error while the real request is in flight.
Future<String?> watchCoupleId(Ref ref) async {
  final session = await ref.watch(sessionProvider.future);
  return session?.coupleId;
}

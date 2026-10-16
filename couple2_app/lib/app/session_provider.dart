import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../core/core.dart';
import '../modules/auth/data/auth_providers.dart';
import 'provider_load.dart';
import 'session.dart';
import 'session_cache.dart';

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

    final cached = await SessionCache.read();
    if (cached != null) {
      unawaited(_refreshFromNetwork());
      return cached;
    }
    return _load();
  }

  Future<void> _refreshFromNetwork() => refresh();

  /// Call after pairing (P0) and on app resume so Home picks up the couple
  /// without a logout. Overlapping callers share one `/auth/me`.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (!ref.mounted) return;
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  Future<Session?> _load() {
    final existing = _loadFlight;
    if (existing != null) return existing;
    final flight = _loadOnce();
    _loadFlight = flight;
    return flight.whenComplete(() {
      if (identical(_loadFlight, flight)) _loadFlight = null;
    });
  }

  Future<Session?> _loadOnce() async {
    final auth = ref.read(authRepositoryProvider);
    if (!await auth.isLoggedIn()) {
      await SessionCache.write(null);
      return null;
    }

    final response = await loadOrTimeout(
      GetIt.I<ICPLHttpClient>().get<Map<String, dynamic>>('/auth/me'),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Resposta inválida de /auth/me');
    }
    final session = Session.fromMe(data);
    await SessionCache.write(session);
    return session;
  }
}

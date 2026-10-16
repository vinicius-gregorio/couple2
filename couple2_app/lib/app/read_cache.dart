import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/core.dart';
import 'provider_load.dart';

/// Keys whose last refresh failed offline while a previous value is still shown.
class StaleReads extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void mark(String key) {
    if (state.contains(key)) return;
    state = {...state, key};
  }

  void clear(String key) {
    if (!state.contains(key)) return;
    state = {...state}..remove(key);
  }

  void clearAll() => state = const {};
}

final staleReadsProvider = NotifierProvider<StaleReads, Set<String>>(
  StaleReads.new,
);

/// Last successful read, in memory and on disk.
///
/// A refresh that fails gives this value back. A cold load with nothing stored
/// still fails, so the screen can show an error card.
class ReadCache {
  static const prefix = 'couple2.read.v1.';
  static final Map<String, Object?> _memory = {};
  static final Set<String> _memoryKeys = {};

  static Future<Object?>? _prefsRead(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefix + key);
    if (raw == null) return const _Missing();
    return jsonDecode(raw);
  }

  /// Null when this key was never stored. A stored null is a real value.
  static Future<Object?> read(String key) async {
    if (_memoryKeys.contains(key)) return _memory[key];
    try {
      final decoded = await _prefsRead(key);
      if (decoded is _Missing) return const _Missing();
      _memoryKeys.add(key);
      _memory[key] = decoded;
      return decoded;
    } catch (_) {
      return const _Missing();
    }
  }

  static Future<void> write(String key, Object? json) async {
    _memoryKeys.add(key);
    _memory[key] = json;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefix + key, jsonEncode(json));
    } catch (_) {
      // Memory still serves this process. The next cold start refetches.
    }
  }

  static Future<void> clear() async {
    _memory.clear();
    _memoryKeys.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(prefix))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

class _Missing {
  const _Missing();
}

Map<String, dynamic> cacheMap(Object? json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return Map<String, dynamic>.from(json);
  throw const FormatException('Cache inválido');
}

/// Loads [load], stores the JSON, and returns the previous value when a later
/// read fails. Marks [staleReadsProvider] after the provider finishes so Home
/// can show the one offline notice without replacing the cards.
Future<T> loadKeepingCache<T>({
  required Ref ref,
  required String key,
  required Future<T> Function() load,
  required Object? Function(T value) encode,
  required T Function(Object? json) decode,
}) async {
  final stored = await ReadCache.read(key);
  final hasCache = stored is! _Missing;
  try {
    final fresh = await loadOrTimeout(load());
    await ReadCache.write(key, encode(fresh));
    _clearStale(ref, key);
    reportConnectivity(true);
    return fresh;
  } on CPLHttpForbiddenException {
    rethrow;
  } catch (error) {
    if (isOfflineFailure(error)) reportConnectivity(false);
    if (hasCache) {
      if (isOfflineFailure(error)) _markStale(ref, key);
      return decode(stored);
    }
    rethrow;
  }
}

void _markStale(Ref ref, String key) {
  Future<void>.microtask(() {
    if (!ref.mounted) return;
    ref.read(staleReadsProvider.notifier).mark(key);
  });
}

void _clearStale(Ref ref, String key) {
  Future<void>.microtask(() {
    if (!ref.mounted) return;
    ref.read(staleReadsProvider.notifier).clear(key);
  });
}

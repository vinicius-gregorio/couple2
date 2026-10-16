import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

/// Last `GET /auth/me` body, so Home can paint before the next round trip.
class SessionCache {
  static const storageKey = 'couple2.session.v1';

  static Future<Session?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return Session.fromCache(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Session? session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (session == null) {
        await prefs.remove(storageKey);
        return;
      }
      await prefs.setString(storageKey, jsonEncode(session.toCacheJson()));
    } catch (_) {
      // A cache miss only delays the first paint. The network load still runs.
    }
  }
}

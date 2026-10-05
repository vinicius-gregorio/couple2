import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/core.dart';
import '../modules/auth/data/auth_providers.dart';

/// Provider para acessar o usuário atual a partir do SharedPreferences
final currentUserProvider = FutureProvider<User?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user');

  if (userJson == null) return null;

  try {
    return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
  } catch (e) {
    return null;
  }
});

/// Provider para ação de logout (pode ser usado em qualquer lugar)
final logoutActionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.logOut();
  };
});

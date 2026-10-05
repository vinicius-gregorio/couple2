import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/auth/data/auth_providers.dart';
import '../modules/notifications/push_service_provider.dart';

export 'session_provider.dart';

/// Provider para ação de logout (pode ser usado em qualquer lugar)
final logoutActionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.logOut();
    await ref.read(pushServiceProvider).stop();
  };
});

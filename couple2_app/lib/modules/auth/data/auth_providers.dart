import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../core/core.dart';
import 'auth_repository.dart';

/// Provider do repositório de autenticação
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

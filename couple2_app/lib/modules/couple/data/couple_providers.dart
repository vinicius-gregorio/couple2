import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'couple_repository.dart';

final coupleRepositoryProvider = Provider<ICoupleRepository>((ref) {
  return CoupleRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final coupleProvider = FutureProvider<Couple?>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null || session.coupleId == null) return null;
  try {
    return await ref.watch(coupleRepositoryProvider).getCouple();
  } on CPLHttpForbiddenException {
    return null;
  }
});

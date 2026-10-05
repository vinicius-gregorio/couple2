import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'mood_repository.dart';
import 'nudges_repository.dart';

final moodRepositoryProvider = Provider<IMoodRepository>((ref) {
  return MoodRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final nudgesRepositoryProvider = Provider<INudgesRepository>((ref) {
  return NudgesRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final currentMoodProvider = FutureProvider<MoodCurrent?>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null || session.coupleId == null) return null;
  try {
    return await ref.watch(moodRepositoryProvider).current();
  } on CPLHttpForbiddenException {
    return null;
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/read_cache.dart';
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
  final coupleId = ref.watch(
    sessionProvider.select((async) => async.asData?.value?.coupleId),
  );
  if (coupleId == null) return null;
  final repo = ref.watch(moodRepositoryProvider);
  try {
    return await loadKeepingCache(
      ref: ref,
      key: 'mood:$coupleId',
      load: () => repo.current(),
      encode: (mood) => mood?.toJson(),
      decode: (json) =>
          json == null ? null : MoodCurrent.fromJson(cacheMap(json)),
    );
  } on CPLHttpForbiddenException {
    return null;
  }
}, retry: noProviderRetry);

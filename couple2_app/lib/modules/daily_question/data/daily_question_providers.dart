import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'daily_question_repository.dart';

final dailyQuestionRepositoryProvider = Provider<IDailyQuestionRepository>((
  ref,
) {
  return DailyQuestionRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final todayQuestionProvider = FutureProvider<CoupleQuestion?>((ref) async {
  final coupleId = ref.watch(
    sessionProvider.select((async) => async.asData?.value?.coupleId),
  );
  if (coupleId == null) return null;
  try {
    return await loadOrTimeout(
      ref.watch(dailyQuestionRepositoryProvider).getToday(),
    );
  } on CPLHttpForbiddenException {
    return null;
  }
}, retry: noProviderRetry);

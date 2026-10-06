import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/auth/data/auth_providers.dart';
import 'session_provider.dart';
import '../modules/auth/ui/pages/auth/auth_viewmodel.dart';
import '../modules/couple/data/couple_providers.dart';
import '../modules/daily_question/data/daily_question_providers.dart';
import '../modules/daily_question/ui/pages/history/question_history_viewmodel.dart';
import '../modules/daily_question/ui/pages/today/today_question_viewmodel.dart';
import '../modules/date_plans/data/date_plans_providers.dart';
import '../modules/feed/data/feed_providers.dart';
import '../modules/feed/ui/pages/feed/feed_viewmodel.dart';
import '../modules/lists/ui/pages/lists/lists_viewmodel.dart';
import '../modules/mood/data/mood_providers.dart';
import '../modules/notifications/push_service_provider.dart';
import '../modules/pairing/data/pairing_providers.dart';

export 'session_provider.dart';

/// Provider para ação de logout (pode ser usado em qualquer lugar)
final logoutActionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.logOut();
    await ref.read(pushServiceProvider).stop();
    _invalidateUserScope(ref);
  };
});

void _invalidateUserScope(Ref ref) {
  ref
    ..invalidate(sessionProvider)
    ..invalidate(authViewModelProvider)
    ..invalidate(coupleProvider)
    ..invalidate(todayQuestionProvider)
    ..invalidate(todayQuestionViewModelProvider)
    ..invalidate(questionHistoryViewModelProvider)
    ..invalidate(listsViewModelProvider)
    ..invalidate(unreadCountProvider)
    ..invalidate(feedPreviewProvider)
    ..invalidate(feedViewModelProvider)
    ..invalidate(currentMoodProvider)
    ..invalidate(nextDateProvider)
    ..invalidate(datePlansChangedProvider)
    ..invalidate(pairingStatusProvider);
}

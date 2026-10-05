import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feed/data/feed_providers.dart';
import '../feed/ui/pages/feed/feed_viewmodel.dart';
import 'data/notifications_providers.dart';
import 'push_service.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    repository: ref.watch(notificationsRepositoryProvider),
    onActivity: () {
      ref.invalidate(unreadCountProvider);
      ref.invalidate(feedPreviewProvider);
      ref.invalidate(feedViewModelProvider);
    },
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'feed_repository.dart';

final feedRepositoryProvider = Provider<IFeedRepository>((ref) {
  return FeedRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final coupleId = await watchCoupleId(ref);
  if (coupleId == null) return 0;
  final repo = ref.watch(feedRepositoryProvider);
  try {
    return await loadOrTimeout(repo.unreadCount());
  } on CPLHttpForbiddenException {
    return 0;
  }
}, retry: noProviderRetry);

final feedPreviewProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final coupleId = await watchCoupleId(ref);
  if (coupleId == null) return const [];
  final repo = ref.watch(feedRepositoryProvider);
  try {
    return await loadOrTimeout(() async {
      final page = await repo.getFeed(limit: 3);
      return page.items;
    }());
  } on CPLHttpForbiddenException {
    return const [];
  }
}, retry: noProviderRetry);

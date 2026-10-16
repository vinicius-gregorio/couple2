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
  final coupleId = ref.watch(
    sessionProvider.select((async) => async.asData?.value?.coupleId),
  );
  if (coupleId == null) return 0;
  try {
    return await loadOrTimeout(ref.watch(feedRepositoryProvider).unreadCount());
  } on CPLHttpForbiddenException {
    return 0;
  }
}, retry: noProviderRetry);

final feedPreviewProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final coupleId = ref.watch(
    sessionProvider.select((async) => async.asData?.value?.coupleId),
  );
  if (coupleId == null) return const [];
  try {
    final page = await loadOrTimeout(
      ref.watch(feedRepositoryProvider).getFeed(limit: 3),
    );
    return page.items;
  } on CPLHttpForbiddenException {
    return const [];
  }
}, retry: noProviderRetry);

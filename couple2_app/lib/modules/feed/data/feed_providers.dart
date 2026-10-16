import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/read_cache.dart';
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
    return await loadKeepingCache(
      ref: ref,
      key: 'unread:$coupleId',
      load: () => repo.unreadCount(),
      encode: (count) => count,
      decode: (json) => json is int ? json : 0,
    );
  } on CPLHttpForbiddenException {
    return 0;
  }
}, retry: noProviderRetry);

final feedPreviewProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final coupleId = await watchCoupleId(ref);
  if (coupleId == null) return const [];
  final repo = ref.watch(feedRepositoryProvider);
  try {
    return await loadKeepingCache(
      ref: ref,
      key: 'feed-preview:$coupleId',
      load: () async {
        final page = await repo.getFeed(limit: 3);
        return page.items;
      },
      encode: (items) => [for (final item in items) item.toJson()],
      decode: (json) {
        if (json is! List) return const <ActivityEvent>[];
        return [
          for (final entry in json)
            if (entry is Map)
              ActivityEvent.fromJson(Map<String, dynamic>.from(entry)),
        ];
      },
    );
  } on CPLHttpForbiddenException {
    return const [];
  }
}, retry: noProviderRetry);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'feed_repository.dart';

final feedRepositoryProvider = Provider<IFeedRepository>((ref) {
  return FeedRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null || session.coupleId == null) return 0;
  try {
    return await ref.watch(feedRepositoryProvider).unreadCount();
  } on CPLHttpForbiddenException {
    return 0;
  }
});

final feedPreviewProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null || session.coupleId == null) return const [];
  try {
    final page = await ref.watch(feedRepositoryProvider).getFeed(limit: 3);
    return page.items;
  } on CPLHttpForbiddenException {
    return const [];
  }
});

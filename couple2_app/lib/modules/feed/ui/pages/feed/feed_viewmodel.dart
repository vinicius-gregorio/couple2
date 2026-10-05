import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/session_provider.dart';
import '../../../data/feed_providers.dart';
import '../../../domain/domain.dart';

final feedViewModelProvider =
    NotifierProvider<FeedViewModel, FeedState>(FeedViewModel.new);

class FeedState {
  const FeedState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.items = const [],
    this.nextCursor,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final List<ActivityEvent> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    List<ActivityEvent>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool clearError = false,
  }) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

class FeedViewModel extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future<void>.microtask(_open);
    return const FeedState(isLoading: true);
  }

  Future<void> _open() async {
    try {
      await ref.read(feedRepositoryProvider).markSeen();
      ref.invalidate(unreadCountProvider);
    } catch (_) {
      // Seeing the feed still matters if the cursor write fails.
    }
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref.read(feedRepositoryProvider).getFeed(limit: 20);
      state = FeedState(items: page.items, nextCursor: page.nextCursor);
    } catch (error) {
      state = FeedState(errorMessage: error.toString());
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await ref.read(feedRepositoryProvider).getFeed(
            cursor: cursor,
            limit: 20,
          );
      final seen = state.items.map((item) => item.id).toSet();
      final extra = page.items.where((item) => !seen.contains(item.id));
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...extra],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, errorMessage: error.toString());
    }
  }

  String actorLabel(ActivityEvent event) {
    final me = ref.read(sessionProvider).asData?.value?.id;
    final name = event.payload['actorName'];
    return feedActorLabel(
      actorId: event.actorId,
      currentUserId: me,
      actorName: name is String ? name : null,
    );
  }
}

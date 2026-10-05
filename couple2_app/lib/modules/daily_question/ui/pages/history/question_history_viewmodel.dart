import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/daily_question_providers.dart';
import '../../../domain/domain.dart';

final questionHistoryViewModelProvider =
    NotifierProvider<QuestionHistoryViewModel, QuestionHistoryState>(
      QuestionHistoryViewModel.new,
    );

class QuestionHistoryState {
  const QuestionHistoryState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.errorMessage,
    this.items = const [],
    this.nextCursor,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final String? errorMessage;
  final List<CoupleQuestion> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  QuestionHistoryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    String? errorMessage,
    List<CoupleQuestion>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool clearError = false,
  }) {
    return QuestionHistoryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

class QuestionHistoryViewModel extends Notifier<QuestionHistoryState> {
  @override
  QuestionHistoryState build() {
    Future<void>.microtask(refresh);
    return const QuestionHistoryState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(dailyQuestionRepositoryProvider)
          .history(limit: 20);
      state = QuestionHistoryState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
      ref.invalidate(todayQuestionProvider);
    } catch (error) {
      state = QuestionHistoryState(errorMessage: error.toString());
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(dailyQuestionRepositoryProvider)
          .history(cursor: cursor, limit: 20);
      final seen = state.items.map((item) => item.id).toSet();
      final extra = page.items.where((item) => !seen.contains(item.id));
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...extra],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> answer(String coupleQuestionId, String text) async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updated = await ref
          .read(dailyQuestionRepositoryProvider)
          .answer(coupleQuestionId, text.trim());
      final items = [
        for (final item in state.items)
          if (item.id == updated.id) updated else item,
      ];
      state = state.copyWith(isSaving: false, items: items);
      ref.invalidate(todayQuestionProvider);
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/daily_question_providers.dart';
import '../../../domain/domain.dart';

final todayQuestionViewModelProvider =
    NotifierProvider<TodayQuestionViewModel, TodayQuestionState>(
      TodayQuestionViewModel.new,
    );

class TodayQuestionState {
  const TodayQuestionState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.question,
  });

  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final CoupleQuestion? question;

  TodayQuestionState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    CoupleQuestion? question,
    bool clearError = false,
  }) {
    return TodayQuestionState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      question: question ?? this.question,
    );
  }
}

class TodayQuestionViewModel extends Notifier<TodayQuestionState> {
  @override
  TodayQuestionState build() {
    final cached = ref.read(todayQuestionProvider).asData?.value;
    Future<void>.microtask(load);
    if (cached != null) return TodayQuestionState(question: cached);
    return const TodayQuestionState(isLoading: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final question = await ref
          .read(dailyQuestionRepositoryProvider)
          .getToday();
      state = TodayQuestionState(question: question);
      ref.invalidate(todayQuestionProvider);
    } catch (error) {
      state = TodayQuestionState(errorMessage: error.toString());
    }
  }

  Future<bool> submit(String text) async {
    final question = state.question;
    if (question == null || state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updated = await ref
          .read(dailyQuestionRepositoryProvider)
          .answer(question.id, text.trim());
      state = TodayQuestionState(question: updated);
      ref.invalidate(todayQuestionProvider);
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

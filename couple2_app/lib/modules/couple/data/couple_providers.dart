import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'couple_repository.dart';

final coupleRepositoryProvider = Provider<ICoupleRepository>((ref) {
  return CoupleRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final coupleDatesProvider =
    AsyncNotifierProvider<CoupleDatesNotifier, List<CoupleDate>>(
      CoupleDatesNotifier.new,
      retry: noProviderRetry,
    );

/// Dates for the open couple. [remember] publishes a save immediately.
/// [reload] re-reads the list and keeps the previous rows if that read fails.
class CoupleDatesNotifier extends AsyncNotifier<List<CoupleDate>> {
  /// Set when a reload fails and the previous rows stay on screen.
  String? reloadError;

  @override
  Future<List<CoupleDate>> build() {
    final coupleId = ref.watch(
      sessionProvider.select((async) => async.asData?.value?.coupleId),
    );
    if (coupleId == null) return Future.value(const []);
    return loadOrTimeout(ref.watch(coupleRepositoryProvider).getDates());
  }

  void remember(CoupleDate date) {
    final current = state.value ?? const <CoupleDate>[];
    state = AsyncData([
      for (final item in current)
        if (item.id != date.id) item,
      date,
    ]);
  }

  Future<void> reload() async {
    final previous = state.value;
    try {
      final coupleId = ref.read(sessionProvider).asData?.value?.coupleId;
      if (coupleId == null) {
        reloadError = null;
        state = const AsyncData([]);
        return;
      }
      final next = await loadOrTimeout(
        ref.read(coupleRepositoryProvider).getDates(),
      );
      reloadError = null;
      state = AsyncData(next);
    } catch (error, stack) {
      if (previous != null) {
        reloadError = userFacingError(error);
        state = AsyncData(List<CoupleDate>.of(previous));
        return;
      }
      reloadError = null;
      state = AsyncError(error, stack);
    }
  }
}

final coupleProvider = FutureProvider<Couple?>((ref) async {
  final coupleId = ref.watch(
    sessionProvider.select((async) => async.asData?.value?.coupleId),
  );
  if (coupleId == null) return null;
  try {
    return await loadOrTimeout(ref.watch(coupleRepositoryProvider).getCouple());
  } on CPLHttpForbiddenException {
    return null;
  }
}, retry: noProviderRetry);

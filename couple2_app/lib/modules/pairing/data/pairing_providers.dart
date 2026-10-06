import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../../couple/data/couple_providers.dart';
import '../domain/domain.dart';
import 'pairing_repository.dart';

final pairingRepositoryProvider = Provider<IPairingRepository>((ref) {
  return PairingRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

/// Null disables polling (tests). The waiting screen and a pending hub poll.
final pairingPollIntervalProvider = Provider<Duration?>((ref) {
  return const Duration(seconds: 4);
});

final pairingStatusProvider =
    AsyncNotifierProvider<PairingStatusNotifier, PairingSnapshot>(
      PairingStatusNotifier.new,
    );

class PairingStatusNotifier extends AsyncNotifier<PairingSnapshot> {
  @override
  Future<PairingSnapshot> build() {
    return ref.read(pairingRepositoryProvider).getStatus();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(pairingRepositoryProvider).getStatus(),
    );
  }

  /// One poll tick. Keeps the previous snapshot when the request fails.
  Future<PairingPhase?> poll() async {
    try {
      final snapshot = await ref.read(pairingRepositoryProvider).getStatus();
      if (snapshot.phase == PairingPhase.paired) {
        await refreshSessionAfterPairing();
      }
      state = AsyncData(snapshot);
      return snapshot.phase;
    } catch (_) {
      return state.asData?.value.phase;
    }
  }

  Future<PairResult> submitCode(String raw) async {
    final code = normalizePairingCode(raw);
    final result = await ref.read(pairingRepositoryProvider).pair(code);
    if (result.phase == PairingPhase.paired) {
      await refreshSessionAfterPairing();
      state = AsyncData(
        PairingSnapshot(
          phase: PairingPhase.paired,
          message: result.message,
          partner: result.partner,
        ),
      );
    } else {
      state = AsyncData(
        PairingSnapshot(
          phase: PairingPhase.pending,
          message: result.message,
          pendingCode: code,
        ),
      );
    }
    return result;
  }

  Future<void> cancelRequest() async {
    await ref.read(pairingRepositoryProvider).cancelRequest();
    await reload();
  }

  /// `GET /auth/me` is what puts `coupleId` on the session. Pairing responses
  /// only carry `partner`.
  Future<void> refreshSessionAfterPairing() async {
    await ref.read(sessionProvider.notifier).refresh();
    ref.invalidate(coupleProvider);
  }

  Future<void> unpair() async {
    await ref.read(pairingRepositoryProvider).unpair();
    await ref.read(sessionProvider.notifier).refresh();
    ref.invalidate(coupleProvider);
    ref.invalidateSelf();
  }
}

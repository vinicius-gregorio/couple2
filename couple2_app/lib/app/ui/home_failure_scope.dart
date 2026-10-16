import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../design_system/widgets/loading_button.dart';

/// Shared heights for a Home card, its skeleton, and its load-error card.
const homeMoodCardHeight = 112.0;
const homeDaysCardHeight = 210.0;
const homeNextDateCardHeight = 160.0;
const homeQuestionCardHeight = 112.0;
const homeFeedCardHeight = 220.0;

/// True after any Home retry starts, so the offline subtitle does not linger.
class HomeOfflineNoticeSuppressed extends Notifier<bool> {
  @override
  bool build() => false;

  void suppress() => state = true;

  void reset() => state = false;
}

final homeOfflineNoticeSuppressedProvider =
    NotifierProvider<HomeOfflineNoticeSuppressed, bool>(
      HomeOfflineNoticeSuppressed.new,
    );

/// Hides the Home offline subtitle for this failure wave.
void noteHomeRetry(WidgetRef ref) {
  ref.read(homeOfflineNoticeSuppressedProvider.notifier).suppress();
}

/// When several Home reads fail offline, the page shows one banner.
class HomeFailureScope extends InheritedWidget {
  const HomeFailureScope({
    super.key,
    required this.collapseOffline,
    required super.child,
  });

  final bool collapseOffline;

  static bool collapse(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HomeFailureScope>()
            ?.collapseOffline ??
        false;
  }

  @override
  bool updateShouldNotify(HomeFailureScope oldWidget) {
    return collapseOffline != oldWidget.collapseOffline;
  }
}

/// One retry, without repeating the offline sentence already shown above.
class QuietRetry extends StatelessWidget {
  const QuietRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: LoadingButton(
        variant: LoadingButtonVariant.text,
        onPressed: onRetry,
        child: const Text('Tentar de novo'),
      ),
    );
  }
}

bool collapseThisError(BuildContext context, Object error) {
  return HomeFailureScope.collapse(context) && isOfflineFailure(error);
}

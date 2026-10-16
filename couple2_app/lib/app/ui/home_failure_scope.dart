import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error.dart';

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
      child: TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
    );
  }
}

bool collapseThisError(BuildContext context, Object error) {
  return HomeFailureScope.collapse(context) && isOfflineFailure(error);
}

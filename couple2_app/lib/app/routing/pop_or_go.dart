import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/widgets/pop_guard.dart';

/// Pops when this page was pushed. A direct open (empty stack) goes to
/// [fallback] instead of leaving a blank navigator.
///
/// [guard] makes a second tap a no-op. Without it, the first pop leaves
/// [BuildContext.canPop] true for the page underneath.
void popOrGo(BuildContext context, String fallback, {PopGuard? guard}) {
  if (!context.mounted) return;
  if (guard != null && !guard.claim(context)) return;
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

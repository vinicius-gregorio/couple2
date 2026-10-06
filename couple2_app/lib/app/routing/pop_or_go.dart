import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pops when this page was pushed. A direct open (empty stack) goes to
/// [fallback] instead of leaving a blank navigator.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

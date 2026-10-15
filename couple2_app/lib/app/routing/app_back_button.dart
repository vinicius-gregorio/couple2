import 'package:flutter/material.dart';

import 'pop_or_go.dart';
import 'routes.dart';

/// Back control that still works after a reload.
///
/// A pushed page pops. A deep link has an empty stack, so the arrow goes to
/// [fallback] instead of disappearing.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = APPRoutes.home});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const BackButtonIcon(),
      onPressed: () => popOrGo(context, fallback),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/button_themes.dart';
import 'mutation_scope.dart';

/// Primary FAB that turns grey when [onPressed] is null.
///
/// The theme has no disabled fill, so a locked add button would stay wine.
class AppFab extends StatelessWidget {
  /// Default FAB diameter. Lists that sit under a FAB pad by [clearance].
  static const double extent = 56;

  /// [Scaffold] end-float margin. Content must clear extent + margin.
  static const double margin = 16;

  /// Bottom padding that keeps the last card above the FAB.
  static const double clearance = extent + margin;

  const AppFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !MutationScope.busyOf(context);
    final background = enabled ? scheme.primary : disabledFill;
    final foreground = enabled
        ? scheme.onPrimary
        : disabledForeground(scheme);
    if (label != null) {
      return FloatingActionButton.extended(
        tooltip: tooltip ?? label,
        onPressed: enabled ? onPressed : null,
        backgroundColor: background,
        foregroundColor: foreground,
        icon: icon,
        label: Text(label!),
      );
    }
    return FloatingActionButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      backgroundColor: background,
      foregroundColor: foreground,
      child: icon,
    );
  }
}

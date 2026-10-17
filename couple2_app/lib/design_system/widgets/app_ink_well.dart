import 'package:flutter/material.dart';

/// Tappable surface. Feature screens use this instead of [InkWell].
class AppInkWell extends StatelessWidget {
  const AppInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  /// Name announced for this tap target. Selectable text on the web does not
  /// merge into the button, so rows pass the label explicitly.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final well = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      child: child,
    );
    final label = semanticLabel;
    if (label == null || label.isEmpty) return well;
    return Semantics(
      button: true,
      enabled: onTap != null || onLongPress != null,
      label: label,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(child: well),
    );
  }
}

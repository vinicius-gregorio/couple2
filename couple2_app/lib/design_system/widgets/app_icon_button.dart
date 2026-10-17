import 'package:flutter/material.dart';

/// Tertiary icon control. Feature screens use this instead of [IconButton].
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.visualDensity,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: visualDensity,
      icon: icon,
    );
  }
}

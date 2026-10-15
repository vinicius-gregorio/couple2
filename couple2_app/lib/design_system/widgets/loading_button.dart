import 'package:flutter/material.dart';

enum LoadingButtonVariant { filled, outlined, text }

/// Button that shows a spinner and ignores taps while a request is in flight.
///
/// Pass the async callback directly. A second tap before the future finishes
/// does nothing. [loading] covers state owned by a view model.
class LoadingButton extends StatefulWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loading = false,
    this.variant = LoadingButtonVariant.filled,
    this.icon,
    this.foregroundColor,
    this.onLongPress,
  });

  /// Sync or async. A returned [Future] keeps the control busy until it ends.
  final Function()? onPressed;
  final bool loading;
  final LoadingButtonVariant variant;
  final Widget child;
  final Widget? icon;
  final Color? foregroundColor;
  final VoidCallback? onLongPress;

  static const spinnerKey = Key('loadingButtonSpinner');

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  var _busy = false;

  bool get _showSpinner => _busy || widget.loading;

  void _press() {
    if (_busy || widget.loading || widget.onPressed == null) return;
    final result = widget.onPressed!();
    if (result is Future) {
      _busy = true;
      setState(() {});
      result.whenComplete(() {
        if (mounted) setState(() => _busy = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !_showSpinner;
    final callback = enabled ? _press : null;
    final accent = widget.foregroundColor;
    final spinnerColor = _spinnerColor(scheme, accent);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_showSpinner) ...[
          SizedBox(
            key: LoadingButton.spinnerKey,
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          ),
          const SizedBox(width: 12),
        ] else if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Flexible(child: widget.child),
      ],
    );
    final style = _style(scheme, accent);

    final longPress = enabled ? widget.onLongPress : null;
    return switch (widget.variant) {
      LoadingButtonVariant.filled => FilledButton(
        onPressed: callback,
        onLongPress: longPress,
        style: style,
        child: label,
      ),
      LoadingButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        onLongPress: longPress,
        style: style,
        child: label,
      ),
      LoadingButtonVariant.text => TextButton(
        onPressed: callback,
        onLongPress: longPress,
        style: style,
        child: label,
      ),
    };
  }

  Color _spinnerColor(ColorScheme scheme, Color? accent) {
    if (widget.variant == LoadingButtonVariant.outlined ||
        widget.variant == LoadingButtonVariant.text) {
      return accent ?? scheme.primary;
    }
    return scheme.onPrimary;
  }

  ButtonStyle? _style(ColorScheme scheme, Color? accent) {
    if (_showSpinner) {
      final filled = widget.variant == LoadingButtonVariant.filled;
      final foreground = filled ? scheme.onPrimary : (accent ?? scheme.primary);
      final background = filled ? scheme.primary : Colors.transparent;
      return ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(background),
        foregroundColor: WidgetStatePropertyAll(foreground),
        side: widget.variant == LoadingButtonVariant.outlined
            ? WidgetStatePropertyAll(
                BorderSide(color: accent ?? scheme.primary, width: 1.5),
              )
            : null,
      );
    }
    if (accent == null) return null;
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return accent;
      }),
      side: widget.variant == LoadingButtonVariant.outlined
          ? WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.12)
                  : accent;
              return BorderSide(color: color, width: 1.5);
            })
          : null,
    );
  }
}

class LoadingIconButton extends StatefulWidget {
  const LoadingIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.loading = false,
    this.tooltip,
  });

  /// Sync or async. A returned [Future] keeps the control busy until it ends.
  final Function()? onPressed;
  final bool loading;
  final Widget icon;
  final String? tooltip;

  @override
  State<LoadingIconButton> createState() => _LoadingIconButtonState();
}

Widget _tinted(Widget icon, Color color) {
  if (icon is Icon) {
    return Icon(
      icon.icon,
      key: icon.key,
      size: icon.size,
      color: color,
      semanticLabel: icon.semanticLabel,
      textDirection: icon.textDirection,
    );
  }
  return IconTheme.merge(
    data: IconThemeData(color: color),
    child: icon,
  );
}

class _LoadingIconButtonState extends State<LoadingIconButton> {
  var _busy = false;

  bool get _showSpinner => _busy || widget.loading;

  void _press() {
    if (_busy || widget.loading || widget.onPressed == null) return;
    final result = widget.onPressed!();
    if (result is Future) {
      _busy = true;
      setState(() {});
      result.whenComplete(() {
        if (mounted) setState(() => _busy = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !_showSpinner;
    final background = enabled || _showSpinner
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final foreground = enabled || _showSpinner
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: 0.38);
    return IconButton.filled(
      tooltip: widget.tooltip,
      onPressed: enabled ? _press : null,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
      ),
      icon: _showSpinner
          ? SizedBox(
              key: LoadingButton.spinnerKey,
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : _tinted(widget.icon, foreground),
    );
  }
}

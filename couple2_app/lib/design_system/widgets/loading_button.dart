import 'package:flutter/material.dart';

import 'mutation_scope.dart';

enum LoadingButtonVariant { filled, outlined, text }

/// Fixed-size spinner. A bare indicator collapses to a hairline on web.
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: LoadingButton.spinnerKey,
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: color ?? scheme.primary,
      ),
    );
  }
}

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
    final scope = MutationScope.maybeOf(context);
    if (scope != null && scope.busy) return;
    final action = widget.onPressed;
    if (action == null) return;
    if (scope != null && !scope.claim(this)) return;
    _busy = true;
    try {
      final result = action();
      if (result is Future) {
        setState(() {});
        result.whenComplete(() {
          scope?.release(this);
          if (mounted) setState(() => _busy = false);
        });
      } else {
        _busy = false;
        scope?.release(this);
      }
    } catch (_) {
      _busy = false;
      scope?.release(this);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scopeBusy =
        MutationScope.busyOf(context) &&
        !(MutationScope.maybeOf(context)?.owns(this) ?? false);
    final enabled = widget.onPressed != null && !_showSpinner && !scopeBusy;
    final callback = enabled ? _press : null;
    final accent = widget.foregroundColor;
    final spinnerColor = _spinnerColor(scheme, accent);
    final labelColor = _labelColor(theme, scheme, accent);
    final label = IconTheme.merge(
      data: IconThemeData(color: labelColor),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: labelColor),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_showSpinner) ...[
              AppSpinner(size: 22, color: spinnerColor),
              const SizedBox(width: 12),
            ] else if (widget.icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: labelColor),
                child: widget.icon!,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
    final style = _style(theme, scheme, accent);

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

  Color _disabledForeground(ThemeData theme, ColorScheme scheme) {
    return theme.filledButtonTheme.style?.foregroundColor?.resolve({
          WidgetState.disabled,
        }) ??
        scheme.onSurface.withValues(alpha: 0.38);
  }

  /// Filled labels stay white on [ColorScheme.primary], including while the
  /// control is locked. A disabled style would paint a dark label on the wine
  /// fill and hide the spinner.
  Color _labelColor(ThemeData theme, ColorScheme scheme, Color? accent) {
    final disabled = _disabledForeground(theme, scheme);
    if (widget.variant == LoadingButtonVariant.filled) {
      if (_showSpinner || widget.onPressed != null) return scheme.onPrimary;
      return disabled;
    }
    if (!_showSpinner && widget.onPressed == null) return disabled;
    return accent ?? scheme.primary;
  }

  ButtonStyle? _style(ThemeData theme, ColorScheme scheme, Color? accent) {
    if (widget.variant == LoadingButtonVariant.filled && accent == null) {
      final disabledBg =
          theme.filledButtonTheme.style?.backgroundColor?.resolve({
            WidgetState.disabled,
          }) ??
          scheme.surfaceContainerHighest;
      final disabledFg = _disabledForeground(theme, scheme);
      final spinning = _showSpinner;
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (spinning) return scheme.primary;
          if (states.contains(WidgetState.disabled)) return disabledBg;
          return scheme.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (spinning) return scheme.onPrimary;
          if (states.contains(WidgetState.disabled)) return disabledFg;
          return scheme.onPrimary;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (spinning) return scheme.onPrimary;
          if (states.contains(WidgetState.disabled)) return disabledFg;
          return scheme.onPrimary;
        }),
      );
    }
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
    final scope = MutationScope.maybeOf(context);
    if (scope != null && scope.busy) return;
    final action = widget.onPressed;
    if (action == null) return;
    if (scope != null && !scope.claim(this)) return;
    _busy = true;
    try {
      final result = action();
      if (result is Future) {
        setState(() {});
        result.whenComplete(() {
          scope?.release(this);
          if (mounted) setState(() => _busy = false);
        });
      } else {
        _busy = false;
        scope?.release(this);
      }
    } catch (_) {
      _busy = false;
      scope?.release(this);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scopeBusy =
        MutationScope.busyOf(context) &&
        !(MutationScope.maybeOf(context)?.owns(this) ?? false);
    final enabled = widget.onPressed != null && !_showSpinner && !scopeBusy;
    final foreground = enabled || _showSpinner
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.38);
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: enabled ? _press : null,
      icon: _showSpinner
          ? AppSpinner(size: 22, color: scheme.primary)
          : _tinted(widget.icon, foreground),
    );
  }
}

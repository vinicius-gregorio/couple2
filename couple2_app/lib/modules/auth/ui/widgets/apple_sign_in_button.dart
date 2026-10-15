import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Styled "Sign in with Apple" button. Sign-in runs through Firebase Auth.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  static const loadingIndicatorKey = Key('appleSignInLoading');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isLoading || onPressed != null;
    final enabled = !isLoading && onPressed != null;
    final background = active
        ? scheme.inverseSurface
        : scheme.surfaceContainerHighest;
    final foreground = active
        ? scheme.onInverseSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: isLoading
          ? SizedBox(
              key: loadingIndicatorKey,
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : const Icon(Icons.apple, size: 24),
      label: const AppText('Entrar com Apple'),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}
